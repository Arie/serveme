# typed: false
# frozen_string_literal: true

class LogParser
  MIN_MATCH_DURATION_SECONDS = 300
  MINI_ROUND_LENGTH_REGEX = /Mini_Round_Length.*seconds\s+"([\d.]+)"/

  PlayerStats = Struct.new(:steam_uid, :name, :team_counts, :class_counts, :kills, :assists, :deaths, :damage, :damage_taken, :healing, :heals_received, :ubers, :drops, :airshots, :caps, keyword_init: true) do
    def team
      team_counts.max_by { |_, count| count }&.first
    end

    def tf2_class
      class_counts.max_by { |_, count| count }&.first || "unknown"
    end
  end

  MatchData = Struct.new(:players, :round_wins, :round_lengths, :final_scores, :match_ended, :total_duration_seconds, keyword_init: true)

  attr_reader :filepath

  def initialize(filepath)
    @filepath = filepath
  end

  def perform
    parse_log
    @completed_matches.select { |m| valid_match?(m) }
  end

  private

  def parse_log
    @completed_matches = []
    @steam_id_cache = {}
    reset_match_state

    File.open(filepath, "r") do |file|
      file.each_line do |line|
        process_line(line)
      end
    end

    # Finalize any in-progress match
    finalize_match if @players.any?
  end

  def reset_match_state
    @players = {}
    @round_wins = Hash.new(0)
    @round_lengths = []
    @final_scores = {}
    @match_ended = false
    @between_matches = true
    @between_rounds = false
  end

  def finalize_match
    match = build_match_data
    @completed_matches << match
    reset_match_state
  end

  def process_line(raw_line)
    line = sanitize_line(raw_line)
    event = parse_event(line)
    return unless event

    case event
    when TF2LineParser::Events::RoundStart
      @between_matches = false
      @between_rounds = false
    when TF2LineParser::Events::MatchEnd
      @match_ended = true
      finalize_match
    when TF2LineParser::Events::RoundWin
      @between_rounds = true
      handle_round_win(event)
    when TF2LineParser::Events::RoundLength
      handle_round_length(event)
    when TF2LineParser::Events::Unknown
      handle_mini_round_length(event)
    when TF2LineParser::Events::FinalScore
      handle_final_score(event)
    when TF2LineParser::Events::CurrentScore
      handle_current_score(event)
    else
      return if @between_matches || @between_rounds

      case event
      when TF2LineParser::Events::Kill
        handle_kill(event)
      when TF2LineParser::Events::Airshot
        handle_airshot(event)
        handle_damage(event)
      when TF2LineParser::Events::Damage
        handle_damage(event)
      when TF2LineParser::Events::Assist
        handle_assist(event)
      when TF2LineParser::Events::Heal
        handle_heal(event)
      when TF2LineParser::Events::Spawn
        handle_spawn(event)
      when TF2LineParser::Events::RoleChange
        handle_role_change(event)
      when TF2LineParser::Events::ChargeDeployed
        handle_charge_deployed(event)
      when TF2LineParser::Events::MedicDeath
        handle_medic_death(event)
      when TF2LineParser::Events::PointCapture
        handle_point_capture(event)
      when TF2LineParser::Events::Suicide
        handle_suicide(event)
      end
    end
  end

  def parse_event(line)
    TF2LineParser::Parser.parse(line)
  rescue StandardError
    nil
  end

  ANSI_REGEX = /\e\[\d*;?\d*m\[?K?/

  def sanitize_line(line)
    cleaned = line.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    cleaned.gsub(ANSI_REGEX, "")
  rescue StandardError
    StringSanitizer.tidy_bytes(line).gsub(ANSI_REGEX, "")
  end

  def handle_kill(event)
    attacker = find_or_create_player(event.player)
    target = find_or_create_player(event.target)
    return unless attacker && target

    attacker.kills += 1
    target.deaths += 1
    track_team(attacker, event.player)
    track_team(target, event.target)
  end

  def handle_damage(event)
    player = find_or_create_player(event.player)
    dmg = event.damage || 0

    if player
      player.damage += dmg
      track_team(player, event.player)
    end

    target = find_or_create_player(event.target)
    return unless target

    target.damage_taken += dmg
    track_team(target, event.target)
  end

  def handle_assist(event)
    player = find_or_create_player(event.player)
    return unless player

    player.assists += 1
    track_team(player, event.player)
  end

  def handle_heal(event)
    heals = event.healing || event.value || 0

    player = find_or_create_player(event.player)
    if player
      player.healing += heals
      track_team(player, event.player)
    end

    target = find_or_create_player(event.target)
    return unless target

    target.heals_received += heals
    track_team(target, event.target)
  end

  def handle_spawn(event)
    player = find_or_create_player(event.player)
    return unless player

    role = normalize_class(event.role)
    player.class_counts[role] += 1
    track_team(player, event.player)
  end

  def handle_role_change(event)
    player = find_or_create_player(event.player)
    return unless player

    role = normalize_class(event.role)
    player.class_counts[role] += 1
    track_team(player, event.player)
  end

  def handle_round_win(event)
    @round_wins[event.team] += 1 if event.team
  end

  def handle_round_length(event)
    @round_lengths << event.length.to_f if event.length
  end

  def handle_mini_round_length(event)
    return unless event.unknown

    match = event.unknown.match(MINI_ROUND_LENGTH_REGEX)
    @round_lengths << match[1].to_f if match
  end

  def handle_final_score(event)
    @final_scores[event.team] = event.score.to_i if event.team
  end

  def handle_current_score(event)
    @final_scores[event.team] = event.score.to_i if event.team
  end

  def handle_charge_deployed(event)
    player = find_or_create_player(event.player)
    return unless player

    player.ubers += 1
    track_team(player, event.player)
  end

  def handle_medic_death(event)
    medic = find_or_create_player(event.target)
    return unless medic

    medic.drops += 1 if event.ubercharge
    track_team(medic, event.target)
  end

  def handle_airshot(event)
    player = find_or_create_player(event.player)
    return unless player

    player.airshots += 1
    track_team(player, event.player)
  end

  def handle_point_capture(event)
    event.cappers.each do |capper|
      steam_uid = convert_steam_id(capper.steam_id)
      next unless steam_uid

      player = @players[steam_uid]
      next unless player

      player.caps += 1
    end
  end

  def handle_suicide(event)
    player = find_or_create_player(event.player)
    return unless player

    player.deaths += 1
    track_team(player, event.player)
  end

  def find_or_create_player(event_player)
    return nil unless event_player&.steam_id

    steam_uid = convert_steam_id(event_player.steam_id)
    return nil unless steam_uid

    @players[steam_uid] ||= PlayerStats.new(
      steam_uid: steam_uid,
      name: event_player.name,
      team_counts: Hash.new(0),
      class_counts: Hash.new(0),
      kills: 0,
      assists: 0,
      deaths: 0,
      damage: 0,
      damage_taken: 0,
      healing: 0,
      heals_received: 0,
      ubers: 0,
      drops: 0,
      airshots: 0,
      caps: 0
    )
  end

  def track_team(player_stats, event_player)
    team = event_player.team
    player_stats.team_counts[team] += 1 if team.present? && team.in?(%w[Red Blue])
  end

  def convert_steam_id(steam_id)
    return nil if steam_id.blank? || steam_id.in?(%w[Console BOT])

    return @steam_id_cache[steam_id] if @steam_id_cache.key?(steam_id)

    @steam_id_cache[steam_id] = SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
  rescue SteamCondenser::Error
    @steam_id_cache[steam_id] = nil
  end

  def normalize_class(role)
    return "unknown" unless role

    case role.downcase
    when "scout" then "scout"
    when "soldier" then "soldier"
    when "pyro" then "pyro"
    when "demoman" then "demoman"
    when "heavyweapons", "heavy" then "heavyweapons"
    when "engineer" then "engineer"
    when "medic" then "medic"
    when "sniper" then "sniper"
    when "spy" then "spy"
    else "unknown"
    end
  end

  def valid_match?(match)
    match.total_duration_seconds >= MIN_MATCH_DURATION_SECONDS
  end

  def build_match_data
    players = @players.values.select { |p| p.team.present? }

    MatchData.new(
      players: players,
      round_wins: @round_wins.dup,
      round_lengths: @round_lengths.dup,
      final_scores: @final_scores.dup,
      match_ended: @match_ended,
      total_duration_seconds: @round_lengths.sum
    )
  end
end
