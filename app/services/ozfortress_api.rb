# typed: false
# frozen_string_literal: true

class OzfortressApi
  BASE_URL = "https://ozfortress.com/api/v1"

  class << self
    def steam_id_for_discord(discord_uid)
      return nil unless api_key.present?

      response = connection.get("users/discord_id/#{discord_uid}")

      return nil unless response.success?

      data = JSON.parse(response.body)
      data.dig("user", "steam_64_str")
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.warn "OzfortressApi error: #{e.message}"
      nil
    end

    private

    def api_key
      Rails.application.credentials.dig(:ozfortress, :api_key)
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :url_encoded
        f.headers["X-API-Key"] = api_key
        f.headers["Accept"] = "application/json"
        f.options.timeout = 5
        f.options.open_timeout = 2
        f.adapter Faraday.default_adapter
      end
    end
  end
end
