# typed: false
# frozen_string_literal: true

module ServemeBot
  module Helpers
    module FlagHelper
      # Special mappings for non-standard codes
      FLAG_MAPPINGS = {
        "uk" => "gb",
        "en" => "england",
        "scotland" => "scotland",
        "europeanunion" => "eu"
      }.freeze

      def self.to_discord_emoji(flag_code)
        return ":globe_with_meridians:" if flag_code.nil? || flag_code.to_s.strip.empty?

        code = flag_code.to_s.downcase
        mapped = FLAG_MAPPINGS[code] || code

        # England and Scotland use special Discord emojis (not :flag_xx:)
        case mapped
        when "england"
          ":england:"
        when "scotland"
          ":scotland:"
        else
          ":flag_#{mapped}:"
        end
      end
    end
  end
end
