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

    Sidekiq.redis { |conn| conn.pubsub(:numsub, full_channel).last.to_i > 0 }
  rescue
    true
  end

  # Check if there are subscribers for a model-based Turbo Stream (e.g., a Reservation)
  # Model streams use signed channel names unlike plain string streams
  def self.has_model_subscribers?(streamable)
    cable_config = ActionCable.server.config.cable
    return true unless cable_config["adapter"] == "redis"

    signed = Turbo::StreamsChannel.signed_stream_name(streamable)
    prefix = cable_config["channel_prefix"]
    full_channel = "#{prefix}:Turbo::StreamsChannel:#{signed}"

    Sidekiq.redis { |conn| conn.pubsub(:numsub, full_channel).last.to_i > 0 }
  rescue
    true
  end
end
