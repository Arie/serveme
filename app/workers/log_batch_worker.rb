# typed: false
# frozen_string_literal: true

# LogBatchWorker processes batches of log lines for improved performance.
#
# Key optimization: Instead of creating one Sidekiq job per log line (500 jobs/sec at peak),
# the logdaemon batches lines (10 lines or 100ms) and creates ONE job for the entire batch.
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
      # Delegate to LogWorker for all business logic
      worker = LogWorker.new
      worker.skip_broadcast = true  # Prevent individual broadcasts - we'll batch them

      # Process the line normally (handles connects, chat, bans, etc.)
      worker.perform(raw_line)

      # Extract logsecret for batch broadcasting
      matches = raw_line.match(LogWorker::LOG_LINE_REGEX)
      if matches && matches[:line] && matches[:secret].present?
        grouped_lines[matches[:secret]] << matches[:line]
      end
    end

    # Batch broadcast collected lines per reservation
    batch_broadcast_lines(grouped_lines)
  end

  private

  def batch_broadcast_lines(grouped_lines)
    grouped_lines.each do |logsecret, lines|
      next if lines.empty?

      user_stream = "reservation_#{logsecret}_log_lines"
      admin_stream = "#{user_stream}_admin"

      # Check for subscribers before rendering (optimization)
      has_user_subscribers = TurboSubscriberChecker.has_subscribers?(user_stream)
      has_admin_subscribers = TurboSubscriberChecker.has_subscribers?(admin_stream)

      next unless has_user_subscribers || has_admin_subscribers

      # Batch render user lines (if there are subscribers)
      if has_user_subscribers
        # Filter out admin-only events for user stream
        user_lines = lines.reject { |line| admin_only_event?(line) }

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
        html = ApplicationController.render(
          partial: "reservations/log_line",
          collection: lines,
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
