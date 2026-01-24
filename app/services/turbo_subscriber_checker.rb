# typed: false
# frozen_string_literal: true

class TurboSubscriberChecker
  # Check if there are any active subscribers to a Turbo Streams channel
  # Uses Redis PUBSUB NUMSUB command to query subscriber count directly
  #
  # @param stream_name [String] The stream name (e.g., "reservation_123_log_lines")
  # @return [Boolean] true if there are active subscribers (or true by default if not using Redis)
  def self.has_subscribers?(stream_name)
    cable_config = ActionCable.server.config.cable
    # If not using Redis adapter, default to true (always broadcast)
    return true unless cable_config["adapter"] == "redis"

    prefix = cable_config["channel_prefix"]
    full_channel = "#{prefix}:#{stream_name}"

    result = redis.pubsub(:numsub, full_channel)
    # PUBSUB NUMSUB returns [channel_name, subscriber_count]
    result.last.to_i > 0
  end

  def self.redis
    cable_config = ActionCable.server.config.cable
    @redis ||= Redis.new(url: cable_config["url"] || "redis://localhost:6379")
  end
end
