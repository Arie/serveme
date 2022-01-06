# frozen_string_literal: true

class RconAutocomplete
  def self.autocomplete(query)
    deep_suggestions = autocomplete_deep_suggestions(query)

    return deep_suggestions.first(5) if deep_suggestions

    suggestions = autocomplete_exact_start(query)

    return suggestions.first(5) if suggestions

    autocomplete_best_match(query).first(5)
  end

  def self.autocomplete_deep_suggestions(query)
    send("autocomplete_deep_#{query.split.first}", query.split[1..]) if deep_complete_commands.any? { |command| query.start_with?(command) }
  end

  def self.autocomplete_deep_changelevel(query)
    autocomplete_maps
      .select { |map_name| map_name.start_with?(query.join(' ')) }
      .map { |map_name| "changelevel #{map_name}" }
      .sort
  end

  def self.autocomplete_deep_exec(query)
    league_configs
      .select { |config| config.start_with?(query.join(' ')) }
      .map { |config| "exec #{config}" }
      .sort
  end

  def self.autocomplete_exact_start(query)
    commands_to_suggest
      .select { |command| command.start_with?(query) }
      .sort_by { |command| Text::Levenshtein.distance(command, query) }
  end

  def self.autocomplete_best_match(query)
    commands_to_suggest
      .sort_by { |command| Text::Levenshtein.distance(command, query) }
  end

  def self.deep_complete_commands
    %w[
      changelevel
      exec
    ]
  end

  def self.league_configs
    %w[
      etf2l
      etf2l_6v6
      etf2l_6v6_5cp
      etf2l_6v6_ctf
      etf2l_6v6_koth
      etf2l_6v6_stopwatch
      etf2l_9v9
      etf2l_9v9_5cp
      etf2l_9v9_ctf
      etf2l_9v9_koth
      etf2l_9v9_stopwatch
      etf2l_bball
      etf2l_golden_cap
      etf2l_ultiduo

      rgl_6s_5cp_gc
      rgl_6s_5cp_match
      rgl_6s_5cp_match_half1
      rgl_6s_5cp_match_half2
      rgl_6s_5cp_scrim
      rgl_6s_koth_bo5
      rgl_6s_koth
      rgl_6s_koth_match
      rgl_6s_koth_scrim
      rgl_7s_koth_bo5
      rgl_7s_koth
      rgl_7s_stopwatch
      rgl_HL_koth_bo5
      rgl_HL_koth
      rgl_HL_stopwatch
      rgl_mm_5cp
      rgl_mm_koth_bo5
      rgl_mm_koth
      rgl_mm_stopwatch
      rgl_off
    ]
  end

  def self.autocomplete_maps
    %w[
      cp_gullywash_f4a
      cp_gullywash_f5
      cp_metalworks
      cp_metalworks_f2
      cp_process_f9a
      cp_reckoner_rc6
      cp_snakewater_final1
      cp_sunshine
      koth_clearcut_b15d

      cp_granary_pro2
      cp_steel_f6
      cp_steel_f8
      cp_villa_b18
      koth_ashville_rc2d
      koth_bagel_rc5
      koth_cascade_rc2
      koth_lakeside_r2
      koth_product_final
      pl_vigil_rc7
      pl_vigil_rc8
      pl_swiftwater_final1
      pl_upward
    ]
  end

  def self.commands_to_suggest
    %w[
      banid
      banip
      changelevel
      exec
      host_timescale
      kick
      kickall
      kickid
      mp_disable_respawn_times
      mp_friendlyfire
      mp_tournament_restart
      mp_tournament_whitelist
      say
      sv_alltalk
      sv_cheats
      sv_gravity
      tf_bot_add
      tf_bot_difficulty
      tf_bot_kick
      tf_bot_kill
      tf_bot_quota
      tf_forced_holiday
      tf_use_fixed_weaponspreads
      tv_delay
      tv_delaymapchange_protect
    ]
  end
end
