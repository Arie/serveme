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
    return true unless cable_config["adapter"] == "redis"

    prefix = cable_config["channel_prefix"]
    full_channel = "#{prefix}:#{stream_name}"

    numsub_result = Sidekiq.redis { |conn| conn.call("PUBSUB", "NUMSUB", full_channel) }
    numsub_result.last.to_i > 0
  rescue StandardError
    true
  end

  # Check if there are subscribers for a model-based Turbo Stream (e.g., a Reservation)
  # Model streams use the unsigned stream name (GlobalID) as the Redis channel, not the signed token
  def self.has_model_subscribers?(streamable)
    cable_config = ActionCable.server.config.cable
    return true unless cable_config["adapter"] == "redis"

    unsigned = streamable.to_gid_param
    prefix = cable_config["channel_prefix"]
    full_channel = "#{prefix}:#{unsigned}"

    numsub_result = Sidekiq.redis { |conn| conn.call("PUBSUB", "NUMSUB", full_channel) }
    numsub_result.last.to_i > 0
  rescue StandardError
    true
  end
end
