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

    suggestions = autocomplete_exact_start.sort_by { |command| command[:command] }

    return suggestions.first(5) if suggestions

    autocomplete_best_match.first(5).sort_by { |command| command[:command] }
  end

  def autocomplete_deep_suggestions
    send("autocomplete_deep_#{query.split.first}") if self.class.deep_complete_commands.any? { |command| query.start_with?(command[:command]) }
  end

  def autocomplete_deep_changelevel
    self.class.autocomplete_maps
        .select { |map_name| map_name.downcase.start_with?(query.split[1..].join(' ')) }
        .map { |map_name| { command: "changelevel #{map_name}", description: 'Changes the map' } }
        .sort_by { |command| command[:command] }
  end

  def autocomplete_deep_exec
    self.class.league_configs
        .select { |config| config.downcase.start_with?(query.split[1..].join(' ')) }
        .map { |config| { command: "exec #{config}", description: 'Executes a config' } }
        .sort_by { |command| command[:command] }
  end

  def autocomplete_deep_kick
    autocomplete_players
      .map do |ps|
        uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(ps.reservation_player.steam_uid.to_i)
        { command: "kickid \"#{uid3}\"", display_text: "kick \"#{ps.reservation_player.name}\"", description: "Kick #{ps.reservation_player.name}" }
      end
  end

  def autocomplete_deep_ban
    autocomplete_players
      .map do |ps|
        uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(ps.reservation_player.steam_uid.to_i)
        { command: "banid 0 \"#{uid3}\" kick", display_text: "ban \"#{ps.reservation_player.name}\"", description: "Ban #{ps.reservation_player.name}" }
      end
  end

  def autocomplete_deep_ban_id() = autocomplete_deep_ban

  def autocomplete_players
    PlayerStatistic
      .joins(:reservation_player)
      .order('lower(reservation_players.name) ASC')
      .where('reservation_players.reservation_id = ?', reservation.id)
      .where('player_statistics.created_at > ?', 90.seconds.ago)
      .to_a
      .uniq { |ps| ps.reservation_player.steam_uid }
  end

  def autocomplete_exact_start
    self.class.commands_to_suggest
        .select { |command| command[:command].start_with?(query) }
        .sort_by { |command| Text::Levenshtein.distance(command[:command], query) }
  end

  def autocomplete_best_match
    self.class.commands_to_suggest
        .sort_by { |command| Text::Levenshtein.distance(command[:command], query) }
  end

  def self.deep_complete_commands
    [
      { command: 'changelevel', description: 'Change the map' },
      { command: 'exec', description: 'Execute a config' },
      { command: 'kick', description: 'Kick a player by name' },
      { command: 'ban', description: 'Ban a player by name' },
      { command: 'banid', description: 'Ban a player by unique ID' }
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
    [
      { command: 'ban', description: 'Ban a player' },
      { command: 'banid', description: 'Ban a player by ID' },
      { command: 'banip', description: 'Ban an IP address' },
      { command: 'changelevel', description: 'Change the map' },
      { command: 'exec', description: 'Execute a config' },
      { command: 'host_timescale', description: 'Set the timescale' },
      { command: 'kick', description: 'Kick a player by name' },
      { command: 'kickall', description: 'Kick all players' },
      { command: 'kickid', description: 'Kick a player by ID' },
      { command: 'mp_autoteambalance', description: 'Control autoteambalance' },
      { command: 'mp_disable_respawn_times', description: 'Disable respawn times' },
      { command: 'mp_friendlyfire', description: 'Control friendly fire' },
      { command: 'mp_respawnwavetime', description: 'Set the respawn wave time' },
      { command: 'mp_restartround', description: 'Restart the round' },
      { command: 'mp_scrambleteams', description: 'Scramble teams' },
      { command: 'mp_teams_unbalance_limit', description: 'Set the teams unbalance limit' },
      { command: 'mp_timelimit', description: 'Set the map time limit' },
      { command: 'mp_tournament', description: 'Control tournament mode' },
      { command: 'mp_tournament_restart', description: 'Restart the match' },
      { command: 'mp_tournament_whitelist', description: 'Set the whitelist' },
      { command: 'mp_waitingforplayers_cancel', description: 'Cancel the waiting for players' },
      { command: 'mp_winlimit', description: 'Set the match win limit' },
      { command: 'say', description: 'Say something' },
      { command: 'stats', description: 'Show server statistics' },
      { command: 'status', description: 'Show server status' },
      { command: 'sv_alltalk', description: 'Control all talk' },
      { command: 'sv_cheats', description: 'Enable/disable cheats' },
      { command: 'sv_gravity', description: 'Set the gravity' },
      { command: 'tf_bot_add', description: 'Add a bot' },
      { command: 'tf_bot_difficulty', description: 'Set the bot difficulty' },
      { command: 'tf_bot_kick', description: 'Kick a bot' },
      { command: 'tf_bot_kill', description: 'Kill a bot' },
      { command: 'tf_bot_quota', description: 'Set the bot quota' },
      { command: 'tf_forced_holiday', description: 'Control TF2 holiday mode' },
      { command: 'tf_tournament_classlimit_demoman', description: 'Set the demoman class limit' },
      { command: 'tf_tournament_classlimit_engineer', description: 'Set the engineer class limit' },
      { command: 'tf_tournament_classlimit_heavy', description: 'Set the heavy class limit' },
      { command: 'tf_tournament_classlimit_medic', description: 'Set the medic class limit' },
      { command: 'tf_tournament_classlimit_pyro', description: 'Set the pyro class limit' },
      { command: 'tf_tournament_classlimit_scout', description: 'Set the scout class limit' },
      { command: 'tf_tournament_classlimit_sniper', description: 'Set the sniper class limit' },
      { command: 'tf_tournament_classlimit_soldier', description: 'Set the soldier class limit' },
      { command: 'tf_tournament_classlimit_spy', description: 'Set the spy class limit' },
      { command: 'tf_use_fixed_weaponspreads', description: 'Control random weapon spread' },
      { command: 'tf_weapon_criticals', description: 'Toggle critical hits' },
      { command: 'tftrue_whitelist_id', description: 'Set the whitelist with TFTrue' },
      { command: 'tv_delay', description: 'Set the STV delay' },
      { command: 'tv_delaymapchange', description: 'Control map change delay to allow STV to finish broadcasting' },
      { command: 'tv_delaymapchange_protect', description: 'Protect against doing a manual map change if HLTV is broadcasting and has not caught up with a major game event such as round_end' }
    ]
  end
end
