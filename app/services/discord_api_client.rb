# typed: false
# frozen_string_literal: true

class DiscordApiClient
  BASE_URL = "https://discord.com/api/v10"
  RATE_LIMIT_KEY_PREFIX = "discord_rate_limit"

  class << self
    def update_message(channel_id:, message_id:, embed:, components: nil)
      payload = { embeds: [ embed ] }
      payload[:components] = components if components

      # Use channel_id as fallback bucket until we get the real bucket from headers
      request(:patch, "/channels/#{channel_id}/messages/#{message_id}", payload, resource_id: channel_id)
    end

    def update_interaction_response(interaction_token:, content:)
      # Update the original interaction response via webhook
      # This works even after the 15-minute interaction window
      request(:patch, "/webhooks/#{client_id}/#{interaction_token}/messages/@original", { content: content })
    end

    # Check how long to wait before making a request to this resource
    # Returns 0 if we can proceed immediately, or seconds to wait
    def wait_time_for_resource(resource_id)
      Sidekiq.redis do |redis|
        # First check if we have a bucket mapped for this resource
        bucket = redis.get("#{RATE_LIMIT_KEY_PREFIX}:resource:#{resource_id}:bucket")
        return 0 unless bucket

        remaining = redis.get("#{RATE_LIMIT_KEY_PREFIX}:bucket:#{bucket}:remaining")
        reset_at = redis.get("#{RATE_LIMIT_KEY_PREFIX}:bucket:#{bucket}:reset_at")

        return 0 unless remaining && reset_at

        remaining = remaining.to_i
        reset_at = reset_at.to_f

        # If we have requests remaining, no need to wait
        return 0 if remaining > 1

        # Calculate wait time until reset
        wait = reset_at - Time.current.to_f
        wait > 0 ? wait : 0
      end
    end

    private

    def client_id
      Rails.application.credentials.dig(:discord, :"#{region_key}_client_id")
    end

    def request(method, path, body = nil, resource_id: nil)
      uri = URI.parse("#{BASE_URL}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = case method
      when :get
        Net::HTTP::Get.new(uri)
      when :post
        Net::HTTP::Post.new(uri)
      when :patch
        Net::HTTP::Patch.new(uri)
      when :delete
        Net::HTTP::Delete.new(uri)
      end

      request["Authorization"] = "Bot #{bot_token}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json if body

      response = http.request(request)

      # Parse and store rate limit headers from all responses
      store_rate_limit_headers(response, resource_id) if resource_id

      case response.code.to_i
      when 200..299
        JSON.parse(response.body) if response.body.present?
      when 404
        Rails.logger.warn "Discord API 404: #{path} - message may have been deleted"
        nil
      when 429
        retry_after = response["Retry-After"]&.to_f || 1.0
        Rails.logger.warn "Discord API rate limited, retry after #{retry_after}s"
        raise RateLimitError.new(retry_after)
      else
        Rails.logger.error "Discord API error #{response.code}: #{response.body}"
        raise ApiError.new("Discord API error: #{response.code}")
      end
    end

    def store_rate_limit_headers(response, resource_id)
      bucket = response["X-RateLimit-Bucket"]
      remaining = response["X-RateLimit-Remaining"]
      reset_after = response["X-RateLimit-Reset-After"]

      return unless bucket && remaining && reset_after

      Sidekiq.redis do |redis|
        reset_at = Time.current.to_f + reset_after.to_f
        ttl = [ reset_after.to_f.ceil + 1, 60 ].min # Max 60 seconds TTL

        # Map resource to bucket (buckets can be shared across resources)
        redis.set("#{RATE_LIMIT_KEY_PREFIX}:resource:#{resource_id}:bucket", bucket, ex: ttl)

        # Store rate limit info by bucket
        redis.set("#{RATE_LIMIT_KEY_PREFIX}:bucket:#{bucket}:remaining", remaining, ex: ttl)
        redis.set("#{RATE_LIMIT_KEY_PREFIX}:bucket:#{bucket}:reset_at", reset_at.to_s, ex: ttl)
      end
    end

    def bot_token
      Rails.application.credentials.dig(:discord, :"#{region_key}_token")
    end

    def region_key
      case SITE_URL
      when /na\.serveme\.tf/ then "na"
      when /sea\.serveme\.tf/ then "sea"
      when /au\.serveme\.tf/ then "au"
      else "eu"
      end
    end
  end

  class ApiError < StandardError; end

  class RateLimitError < ApiError
    attr_reader :retry_after

    def initialize(retry_after)
      @retry_after = retry_after
      super("Rate limited, retry after #{retry_after}s")
    end
  end
end
