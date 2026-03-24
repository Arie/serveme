# typed: false
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
# - Bulk-fetches reservations (1 query instead of N queries)
# - Batches Turbo Stream broadcasts per reservation (fewer render calls + Redis PUBLISHes)
class LogBatchWorker
  include Sidekiq::Worker
  include LogLineHelper
  sidekiq_options retry: 1

  def perform(log_lines)
    return if log_lines.empty?

    # Process each line using LogWorker, collecting broadcasts for batching
    grouped_lines = Hash.new { |h, k| h[k] = [] }

    log_lines.each do |raw_line|
      worker = LogWorker.new
      worker.skip_broadcast = true
      worker.perform(raw_line)

      # Extract logsecret for batch broadcasting
      matches = raw_line.match(LogWorker::LOG_LINE_REGEX)
      if matches && matches[:line] && matches[:secret].present?
        grouped_lines[matches[:secret]] << matches[:line]
      end
    end

    # Resolve logsecret -> reservation_id once for the whole batch
    reservation_ids = resolve_reservation_ids(grouped_lines.keys)

    # Update live match stats
    update_live_match_stats(grouped_lines, reservation_ids)

    # Broadcast scoreboard updates to reservation show pages
    broadcast_scoreboard_updates(grouped_lines, reservation_ids)

    # Batch broadcast collected lines per reservation
    batch_broadcast_lines(grouped_lines)
  end

  private

  def resolve_reservation_ids(logsecrets)
    result = {}
    logsecrets.each do |logsecret|
      result[logsecret] = Rails.cache.fetch("reservation_secret_#{logsecret}", expires_in: 1.minute) do
        Reservation.where(logsecret: logsecret).pluck(:id).last
      end
    end
    result
  end

  def update_live_match_stats(grouped_lines, reservation_ids)
    grouped_lines.each do |logsecret, lines|
      reservation_id = reservation_ids[logsecret]
      next unless reservation_id

      lines.each { |line| LiveMatchStats.process_line(reservation_id, line) }
    end
  rescue StandardError => e
    Rails.logger.error("[LiveMatchStats] Error updating stats: #{e.message}")
  end

  def broadcast_scoreboard_updates(grouped_lines, reservation_ids)
    grouped_lines.each_key do |logsecret|
      reservation_id = reservation_ids[logsecret]
      next unless reservation_id

      # Throttle scoreboard broadcasts to once per second per reservation
      throttle_key = "scoreboard_throttle:#{reservation_id}"
      next unless Sidekiq.redis { |r| r.set(throttle_key, "1", nx: true, ex: 1) }

      reservation = Reservation.find(reservation_id)
      next unless TurboSubscriberChecker.has_model_subscribers?(reservation)

      # Keep log_listeners alive so logdaemon continues forwarding lines
      Sidekiq.redis { |r| r.set("log_listeners:#{logsecret}", "1", ex: 30) }

      live_stats = LiveMatchStats.get_stats(reservation_id)
      next unless live_stats && live_stats[:players].any?

      reservation_players_by_uid = reservation.reservation_players.index_by(&:steam_uid)
      connection_info = ScoreboardConnectionInfo.for_reservation(reservation)

      html = ApplicationController.render(
        partial: "reservations/match_scoreboard",
        locals: { live_stats: live_stats, reservation_players_by_uid: reservation_players_by_uid, connection_info: connection_info }
      )

      Turbo::StreamsChannel.broadcast_update_to(
        reservation,
        target: "match-scoreboard-#{reservation_id}",
        html: html
      )
    rescue StandardError => e
      Rails.logger.error("[LiveMatchStats] Error broadcasting scoreboard for #{logsecret}: #{e.message}")
    end
  end

  def batch_broadcast_lines(grouped_lines)
    grouped_lines.each do |logsecret, lines|
      next if lines.empty?

      user_stream = "reservation_#{logsecret}_log_lines"
      admin_stream = "#{user_stream}_admin"

      # Check for subscribers before rendering (optimization)
      has_user_subscribers = TurboSubscriberChecker.has_subscribers?(user_stream)
      has_admin_subscribers = TurboSubscriberChecker.has_subscribers?(admin_stream)

      if has_user_subscribers || has_admin_subscribers
        Sidekiq.redis { |r| r.set("log_listeners:#{logsecret}", "1", ex: 30) }
      end

      next unless has_user_subscribers || has_admin_subscribers

      # Batch render user lines (if there are subscribers)
      if has_user_subscribers
        # Filter out admin-only and scoreboard-only events for user stream
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

      # Batch render admin lines (if there are subscribers)
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
end
