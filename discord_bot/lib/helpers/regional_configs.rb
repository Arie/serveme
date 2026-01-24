# typed: false
# frozen_string_literal: true

module ServemeBot
  module Helpers
    class RegionalConfigs
      # Regional config presets for quick selection buttons
      # These are the most commonly used configs per region
      PRESETS = {
        "eu" => %w[
          etf2l_6v6_5cp
          etf2l_6v6_koth
          etf2l_9v9_5cp
          etf2l_9v9_koth
          etf2l_ultiduo
        ],
        "na" => %w[
          rgl_6s_5cp_scrim
          rgl_6s_koth
          rgl_HL_koth
          rgl_7s_koth
          rgl_ud_ultiduo
        ],
        "au" => %w[
          ozfortress_6v6_5cp
          ozfortress_6v6_koth
          ozfortress_hl_5cp
          ozfortress_hl_koth
          ozfortress_ultiduo
        ],
        "sea" => %w[
          afc_6s_5cp_match_pro
          ATF2L_6s_5CP
          ATF2L_6s_koth
          af_HL_koth
          rgl_6s_5cp_scrim
        ]
      }.freeze

      # Config prefixes to prioritize in autocomplete per region
      AUTOCOMPLETE_PRIORITY = {
        "eu" => %w[etf2l],
        "na" => %w[rgl],
        "au" => %w[ozfortress ozf],
        "sea" => %w[afc af ATF2L asiafortress]
      }.freeze

      class << self
        def presets_for_region(region_key)
          PRESETS[region_key] || PRESETS["eu"]
        end

        def priority_prefixes(region_key)
          AUTOCOMPLETE_PRIORITY[region_key] || []
        end

        def prioritized_configs(configs, region_key)
          prefixes = priority_prefixes(region_key)
          return configs if prefixes.empty?

          # Split into priority (regional) and other configs
          priority, other = configs.partition do |config|
            name = config.respond_to?(:file) ? config.file : config.to_s
            prefixes.any? { |prefix| name.downcase.start_with?(prefix.downcase) }
          end

          # Return priority configs first, then others
          priority + other
        end
      end
    end
  end
end
