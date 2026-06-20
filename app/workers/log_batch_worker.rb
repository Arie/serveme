# typed: true
# frozen_string_literal: true

# LogBatchWorker processes batches of log lines for improved performance.
#
# Key optimization: Instead of creating one Sidekiq job per log line (500 jobs/sec at peak),
# the logdaemon batches lines (20 lines or 500ms) and creates ONE job for the entire batch.
#
# This provides a 10× reduction in Sidekiq overhead:
# - 10× fewer job serializations
# - 10× fewer Redis queue operations
# - 10× fewer worker dispatches
#
# Additional optimizations:
# - Reuses parsed data from LogWorker (secret, event, line) instead of re-parsing
# - Batches Turbo Stream broadcasts per reservation (fewer render calls + Redis PUBLISHes)
# - Bulk-loads reservations for scoreboard broadcasts (1 query instead of N)
# - Batches LiveMatchStats Redis operations per reservation
class LogBatchWorker
  include Sidekiq::Worker
  include LogLineHelper
  sidekiq_options retry: 1

  def perform(log_lines)
    return if log_lines.empty?

    grouped_lines = Hash.new { |h, k| h[k] = [] }
    grouped_events = Hash.new { |h, k| h[k] = [] }
    active_logsecrets = Set.new
    preloaded_reservations = preload_reservations(log_lines)

    log_lines.each do |raw_line|
      worker = LogWorker.new
      worker.skip_broadcast = true
      worker.preloaded_reservations = preloaded_reservations
      worker.perform(raw_line)

      secret = worker.parsed_secret
      next unless secret.present? && worker.line.present?

      grouped_lines[secret] << worker.line
      grouped_events[secret] << worker.parsed_event
    end

    reservation_ids = resolve_reservation_ids(grouped_lines.keys)

    update_live_match_stats(grouped_events, reservation_ids)
    broadcast_scoreboard_updates(grouped_lines, reservation_ids, active_logsecrets)
    batch_broadcast_lines(grouped_lines, active_logsecrets)

    set_log_listeners(active_logsecrets)
  end

  private

  def preload_reservations(log_lines)
    secrets = log_lines.filter_map { |line| line.match(LogWorker::LOG_LINE_REGEX)&.[](:secret) }.compact_blank.uniq
    return {} if secrets.empty?

    Reservation.current.where(logsecret: secrets).includes(:user).index_by(&:logsecret)
  end

  def resolve_reservation_ids(logsecrets)
    result = {}
    logsecrets.each do |logsecret|
      result[logsecret] = Rails.cache.fetch("reservation_secret_#{logsecret}", expires_in: 1.minute) do
        Reservation.where(logsecret: logsecret).pluck(:id).last
      end
    end
    result
  end

  def update_live_match_stats(grouped_events, reservation_ids)
    grouped_events.each do |logsecret, events|
      reservation_id = reservation_ids[logsecret]
      next unless reservation_id

      LiveMatchStats.process_events(reservation_id, events)
    end
  rescue StandardError => e
    Rails.logger.error("[LiveMatchStats] Error updating stats: #{e.message}")
  end

  def broadcast_scoreboard_updates(grouped_lines, reservation_ids, active_logsecrets)
    # Bulk-load all reservations needed for scoreboard broadcasts
    needed_ids = grouped_lines.keys.filter_map { |logsecret| reservation_ids[logsecret] }
    return if needed_ids.empty?

    reservations = Reservation.where(id: needed_ids).includes(:reservation_players).index_by(&:id)

    grouped_lines.each_key do |logsecret|
      reservation_id = reservation_ids[logsecret]
      next unless reservation_id

      # Throttle scoreboard broadcasts to once per second per reservation
      throttle_key = "scoreboard_throttle:#{reservation_id}"
      next unless Sidekiq.redis { |r| r.set(throttle_key, "1", nx: true, ex: 1) }

      reservation = reservations[reservation_id]
      next unless reservation
      next unless TurboSubscriberChecker.has_model_subscribers?(reservation)

      active_logsecrets << logsecret

      unless LiveMatchStats.rebuilt?(reservation_id)
        rebuild_from_log(reservation)
      end

      all_match_stats = LiveMatchStats.get_stats(reservation_id)

      next unless all_match_stats&.any?

      reservation_players_by_uid = reservation.reservation_players.index_by(&:steam_uid)
      connection_info = ScoreboardConnectionInfo.for_reservation(reservation)

      # NB: render the v2 stream via BetaBroadcast.render_v2 (which sets
      # request.variant) rather than passing `variants:` to
      # ApplicationController.render — the latter doesn't propagate the variant
      # to nested partials. See BetaBroadcast#render_v2.
      render_scoreboard = ->(v2) do
        all_match_stats.map do |match_stats|
          locals = { live_stats: match_stats, reservation_players_by_uid: reservation_players_by_uid, connection_info: connection_info }
          if v2
            BetaBroadcast.render_v2(partial: "reservations/match_scoreboard", locals: locals)
          else
            ApplicationController.render(partial: "reservations/match_scoreboard", locals: locals)
          end
        end.join
      end

      Turbo::StreamsChannel.broadcast_update_to(
        reservation,
        target: "match-scoreboard-#{reservation_id}",
        html: render_scoreboard.call(false)
      )
      Turbo::StreamsChannel.broadcast_update_to(
        *BetaBroadcast.stream(reservation),
        target: "match-scoreboard-#{reservation_id}",
        html: render_scoreboard.call(true)
      )
    rescue StandardError => e
      Rails.logger.error("[LiveMatchStats] Error broadcasting scoreboard for #{logsecret}: #{e.message}")
    end
  end

  def batch_broadcast_lines(grouped_lines, active_logsecrets)
    grouped_lines.each do |logsecret, lines|
      next if lines.empty?

      user_stream = "reservation_#{logsecret}_log_lines"
      admin_stream = "#{user_stream}_admin"

      has_user_subscribers = TurboSubscriberChecker.has_subscribers?(user_stream)
      has_admin_subscribers = TurboSubscriberChecker.has_subscribers?(admin_stream)

      next unless has_user_subscribers || has_admin_subscribers

      active_logsecrets << logsecret

      if has_user_subscribers
        user_lines = lines.reject { |line| admin_only_event?(line) || scoreboard_only_event?(line) }

        if user_lines.any?
          html = ApplicationController.render(
            partial: "reservations/log_line",
            collection: user_lines,
            as: :log_line,
            locals: { skip_sanitization: false }
          )

          Turbo::StreamsChannel.broadcast_prepend_to(
            user_stream,
            target: user_stream,
            html: html
          )
        end
      end

      if has_admin_subscribers
        admin_lines = lines.reject { |line| scoreboard_only_event?(line) }
        next if admin_lines.empty?

        html = ApplicationController.render(
          partial: "reservations/log_line",
          collection: admin_lines,
          as: :log_line,
          locals: { skip_sanitization: true }
        )

        Turbo::StreamsChannel.broadcast_prepend_to(
          admin_stream,
          target: user_stream,
          html: html
        )
      end
    end
  end

  def rebuild_from_log(reservation)
    filepath = Rails.root.join("log", "streaming", "#{reservation.logsecret}.log").to_s
    LiveMatchStats.rebuild(reservation.id, filepath)
  rescue StandardError => e
    Rails.logger.error("[LiveMatchStats] Error rebuilding from log for reservation #{reservation.id}: #{e.message}")
  end

  def set_log_listeners(active_logsecrets)
    return if active_logsecrets.empty?

    Sidekiq.redis do |r|
      r.pipelined do |p|
        active_logsecrets.each do |logsecret|
          p.set("log_listeners:#{logsecret}", "1", ex: 30)
        end
      end
    end
  end
end
