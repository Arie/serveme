# typed: false
# frozen_string_literal: true

module ServemeBot
  class Config
    class << self
      def load
        # Rails environment is already loaded, just validate we have what we need
        unless discord_token && discord_client_id
          raise "Missing Discord credentials. Set DISCORD_TOKEN and DISCORD_CLIENT_ID " \
                "in environment or Rails credentials."
        end
      end

      def development?
        Rails.env.development?
      end

      def production?
        Rails.env.production?
      end

      # Region key for credential lookup (lowercase)
      def region_key
        case SITE_URL
        when /na\.serveme\.tf/ then "na"
        when /sea\.serveme\.tf/ then "sea"
        when /au\.serveme\.tf/ then "au"
        else "eu"
        end
      end

      # Derive region from SITE_URL (e.g., "https://na.serveme.tf" -> "NA")
      def region_name
        return "Dev" unless production?
        region_key.upcase
      end

      def bot_name
        "serveme.tf #{region_name}"
      end

      # Command name - EU is primary (/serveme), others are prefixed (/serveme-na, etc.)
      def command_name
        region_key == "eu" ? :serveme : :"serveme-#{region_key}"
      end

      def site_url
        SITE_URL
      end

      # Discord credentials - from Rails credentials or ENV
      # Credentials are region-prefixed: eu_token, na_token, etc.
      def discord_token
        ENV["DISCORD_TOKEN"] || Rails.application.credentials.dig(:discord, :"#{region_key}_token")
      end

      def discord_client_id
        ENV["DISCORD_CLIENT_ID"] || Rails.application.credentials.dig(:discord, :"#{region_key}_client_id")
      end

      def dev_guild_id
        # Allow override in production for faster iteration during testing
        # Once stable, remove dev_guild_id from credentials to use global commands
        ENV["DISCORD_DEV_GUILD_ID"] || Rails.application.credentials.dig(:discord, :dev_guild_id)
      end

      # Backwards compatibility
      alias_method :link_base_url, :site_url
    end
  end
end
