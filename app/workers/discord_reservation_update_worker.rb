# typed: false
# frozen_string_literal: true

class DiscordReservationUpdateWorker
  include Sidekiq::Worker

  MIN_DELAY_SECONDS = 1

  sidekiq_options queue: :discord, retry: 3

  # Rate limit errors should retry with the specified delay
  sidekiq_retry_in do |count, exception|
    if exception.is_a?(DiscordApiClient::RateLimitError)
      exception.retry_after + 1
    else
      # Default exponential backoff
      (count ** 4) + 15
    end
  end

  def perform(reservation_id)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation

    notifier = DiscordReservationNotifier.new(reservation)
    return unless notifier.tracking?

    notifier.update
    # RateLimitError is re-raised for Sidekiq retry (excluded from Sentry)
  end

  # Debounce: coalesce rapid updates into a single delayed job
  def self.perform_async(reservation_id)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation&.discord_channel_id

    # Check rate limit status for this channel
    wait_time = DiscordApiClient.wait_time_for_resource(reservation.discord_channel_id)
    delay = [ wait_time.ceil, MIN_DELAY_SECONDS ].max

    debounce_key = "discord_update_pending:#{reservation_id}"

    should_schedule = Sidekiq.redis do |redis|
      # Only schedule if no job is already pending
      # SETNX returns true if key was set (didn't exist)
      redis.set(debounce_key, "1", ex: delay, nx: true)
    end

    # Schedule the job - it will read fresh data from DB when it runs
    perform_in(delay, reservation_id) if should_schedule
  end
end
