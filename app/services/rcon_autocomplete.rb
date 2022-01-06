# frozen_string_literal: true

class RconAutocomplete
  attr_accessor :query, :reservation

  def initialize(reservation = nil)
    @reservation = reservation
  end

  def autocomplete(query)
    @query = query.downcase

    deep_suggestions = autocomplete_deep_suggestions

    return deep_suggestions if deep_suggestions

    suggestions = autocomplete_exact_start.sort

    return suggestions.first(5) if suggestions

    autocomplete_best_match.first(5).sort
  end

  def autocomplete_deep_suggestions
    send("autocomplete_deep_#{query.split.first}") if self.class.deep_complete_commands.any? { |command| query.start_with?(command) }
  end

  def autocomplete_deep_changelevel
    self.class.autocomplete_maps
        .select { |map_name| map_name.downcase.start_with?(query.split[1..].join(' ')) }
        .map { |map_name| "changelevel #{map_name}" }
        .sort
  end

  def autocomplete_deep_exec
    self.class.league_configs
        .select { |config| config.downcase.start_with?(query.split[1..].join(' ')) }
        .map { |config| "exec #{config}" }
        .sort
  end

  def autocomplete_exact_start
    self.class.commands_to_suggest
        .select { |command| command.start_with?(query) }
        .sort_by { |command| Text::Levenshtein.distance(command, query) }
  end

  def autocomplete_best_match
    self.class.commands_to_suggest
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
      mp_autoteambalance
      mp_disable_respawn_times
      mp_friendlyfire
      mp_respawnwavetime
      mp_restartround
      mp_scrambleteams
      mp_teams_unbalance_limit
      mp_timelimit
      mp_tournament
      mp_tournament_restart
      mp_tournament_whitelist
      mp_waitingforplayers_cancel
      mp_winlimit
      say
      stats
      status
      sv_alltalk
      sv_cheats
      sv_gravity
      tf_bot_add
      tf_bot_difficulty
      tf_bot_kick
      tf_bot_kill
      tf_bot_quota
      tf_forced_holiday
      tf_tournament_classlimit_demoman
      tf_tournament_classlimit_engineer
      tf_tournament_classlimit_heavy
      tf_tournament_classlimit_medic
      tf_tournament_classlimit_pyro
      tf_tournament_classlimit_scout
      tf_tournament_classlimit_sniper
      tf_tournament_classlimit_soldier
      tf_tournament_classlimit_spy
      tf_use_fixed_weaponspreads
      tf_weapon_criticals
      tftrue_whitelist_id
      tv_delay
      tv_delaymapchange
      tv_delaymapchange_protect
    ]
  end
end
