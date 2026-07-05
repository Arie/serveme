# typed: true
# frozen_string_literal: true

class TurboSubscriberChecker
  extend T::Sig
  extend Turbo::Streams::StreamName

  # Check if there are any active subscribers to a Turbo Streams channel
  # Uses Redis PUBSUB NUMSUB command to query subscriber count directly
  #
  # @param stream_name [String] The stream name (e.g., "reservation_123_log_lines")
  # @return [Boolean] true if there are active subscribers (or true by default if not using Redis)
  sig { params(stream_name: String).returns(T::Boolean) }
  def self.has_subscribers?(stream_name)
    cable_config = ActionCable.server.config.cable
    return true unless cable_config["adapter"] == "redis"

    prefix = cable_config["channel_prefix"]
    full_channel = "#{prefix}:#{stream_name}"

    numsub_result = Sidekiq.redis { |conn| conn.call("PUBSUB", "NUMSUB", full_channel) }
    numsub_result.last.to_i > 0
  rescue StandardError
    true
  end

  sig { params(streamables: T.untyped).returns(T::Boolean) }
  def self.has_stream_subscribers?(*streamables)
    has_subscribers?(stream_name_from(streamables))
  end
end
