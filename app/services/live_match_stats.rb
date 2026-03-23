# typed: false
# frozen_string_literal: true

class LiveMatchStats
  REDIS_PREFIX = "live_match"
  EXPIRY = 12.hours.to_i

  ANSI_REGEX = /\e\[\d*;?\d*m\[?K?/
  MAP_START_REGEX = /Started map "/

  class << self
    def process_line(reservation_id, raw_line)
      line = sanitize_line(raw_line)

      if line.match?(MAP_START_REGEX)
        clear(reservation_id)
        return
      end

      event = parse_event(line)
      return unless event

      case event
      when TF2LineParser::Events::RoundStart
        set_field(reservation_id, "between_matches", "0")
        set_field(reservation_id, "between_rounds", "0")
      when TF2LineParser::Events::MatchEnd
        set_field(reservation_id, "between_matches", "1")
      when TF2LineParser::Events::RoundWin
        set_field(reservation_id, "between_rounds", "1")
        increment_team_score(reservation_id, event.team) if event.team
      when TF2LineParser::Events::FinalScore
        set_score(reservation_id, event.team, event.score.to_i) if event.team
      when TF2LineParser::Events::CurrentScore
        set_score(reservation_id, event.team, event.score.to_i) if event.team
      else
        return if between_matches?(reservation_id) || between_rounds?(reservation_id)

        case event
        when TF2LineParser::Events::Kill
          handle_kill(reservation_id, event)
        when TF2LineParser::Events::Airshot
          handle_airshot(reservation_id, event)
          handle_damage(reservation_id, event)
        when TF2LineParser::Events::Damage
          handle_damage(reservation_id, event)
        when TF2LineParser::Events::Assist
          handle_assist(reservation_id, event)
        when TF2LineParser::Events::Heal
          handle_heal(reservation_id, event)
        when TF2LineParser::Events::Spawn
          handle_spawn(reservation_id, event)
        when TF2LineParser::Events::RoleChange
          handle_spawn(reservation_id, event)
        when TF2LineParser::Events::ChargeDeployed
          handle_uber(reservation_id, event)
        when TF2LineParser::Events::MedicDeath
          handle_medic_death(reservation_id, event)
        when TF2LineParser::Events::PointCapture
          handle_point_capture(reservation_id, event)
        when TF2LineParser::Events::Suicide
          handle_suicide(reservation_id, event)
        end
      end
    end

    def get_stats(reservation_id)
      key = redis_key(reservation_id)
      data = Sidekiq.redis { |r| r.hgetall(key) }
      return nil if data.empty?

      build_stats_from_redis(data)
    end

    def rebuild(reservation_id, filepath)
      clear(reservation_id)
      return unless File.exist?(filepath)

      File.open(filepath, "r") do |f|
        f.each_line { |line| process_line(reservation_id, line) }
      end
    end

    def clear(reservation_id)
      Sidekiq.redis { |r| r.del(redis_key(reservation_id)) }
    end

    def exists?(reservation_id)
      Sidekiq.redis { |r| r.exists(redis_key(reservation_id)) > 0 }
    end

    private

    def handle_kill(reservation_id, event)
      attacker_uid = steam_uid(event.player)
      target_uid = steam_uid(event.target)
      return unless attacker_uid && target_uid

      increment_stat(reservation_id, attacker_uid, "kills")
      increment_stat(reservation_id, target_uid, "deaths")
      ensure_player(reservation_id, event.player)
      ensure_player(reservation_id, event.target)
    end

    def handle_damage(reservation_id, event)
      uid = steam_uid(event.player)
      target_uid = steam_uid(event.target)
      dmg = event.damage || 0

      if uid
        increment_stat(reservation_id, uid, "damage", dmg)
        ensure_player(reservation_id, event.player)
      end

      return unless target_uid

      increment_stat(reservation_id, target_uid, "damage_taken", dmg)
      ensure_player(reservation_id, event.target)
    end

    def handle_assist(reservation_id, event)
      uid = steam_uid(event.player)
      return unless uid

      increment_stat(reservation_id, uid, "assists")
      ensure_player(reservation_id, event.player)
    end

    def handle_heal(reservation_id, event)
      heals = event.healing || event.value || 0
      uid = steam_uid(event.player)
      target_uid = steam_uid(event.target)

      if uid
        increment_stat(reservation_id, uid, "healing", heals)
        ensure_player(reservation_id, event.player)
      end

      return unless target_uid

      increment_stat(reservation_id, target_uid, "heals_received", heals)
      ensure_player(reservation_id, event.target)
    end

    def handle_spawn(reservation_id, event)
      uid = steam_uid(event.player)
      return unless uid

      role = normalize_class(event.role)
      set_player_field(reservation_id, uid, "tf2_class", role)
      ensure_player(reservation_id, event.player)
    end

    def handle_uber(reservation_id, event)
      uid = steam_uid(event.player)
      return unless uid

      increment_stat(reservation_id, uid, "ubers")
      ensure_player(reservation_id, event.player)
    end

    def handle_medic_death(reservation_id, event)
      uid = steam_uid(event.target)
      return unless uid

      increment_stat(reservation_id, uid, "drops") if event.ubercharge
      ensure_player(reservation_id, event.target)
    end

    def handle_airshot(reservation_id, event)
      uid = steam_uid(event.player)
      return unless uid

      increment_stat(reservation_id, uid, "airshots")
      ensure_player(reservation_id, event.player)
    end

    def handle_point_capture(reservation_id, event)
      event.cappers.each do |capper|
        uid = convert_steam_id(capper.steam_id)
        next unless uid

        increment_stat(reservation_id, uid, "caps")
      end
    end

    def handle_suicide(reservation_id, event)
      uid = steam_uid(event.player)
      return unless uid

      increment_stat(reservation_id, uid, "deaths")
      ensure_player(reservation_id, event.player)
    end

    def ensure_player(reservation_id, event_player)
      uid = steam_uid(event_player)
      return unless uid

      key = redis_key(reservation_id)
      team = event_player.team
      name = event_player.name

      Sidekiq.redis do |r|
        r.hset(key, "player:#{uid}:name", name) if name
        r.hset(key, "player:#{uid}:team", team) if team.present? && team.in?(%w[Red Blue])
        r.expire(key, EXPIRY)
      end
    end

    def increment_stat(reservation_id, uid, stat, amount = 1)
      Sidekiq.redis { |r| r.hincrby(redis_key(reservation_id), "player:#{uid}:#{stat}", amount) }
    end

    def set_player_field(reservation_id, uid, field, value)
      Sidekiq.redis { |r| r.hset(redis_key(reservation_id), "player:#{uid}:#{field}", value) }
    end

    def set_field(reservation_id, field, value)
      key = redis_key(reservation_id)
      Sidekiq.redis do |r|
        r.hset(key, field, value)
        r.expire(key, EXPIRY)
      end
    end

    def set_score(reservation_id, team, score)
      set_field(reservation_id, "score:#{team}", score.to_s)
    end

    def increment_team_score(reservation_id, team)
      Sidekiq.redis { |r| r.hincrby(redis_key(reservation_id), "score:#{team}", 1) }
    end

    def between_matches?(reservation_id)
      Sidekiq.redis { |r| r.hget(redis_key(reservation_id), "between_matches") } != "0"
    end

    def between_rounds?(reservation_id)
      Sidekiq.redis { |r| r.hget(redis_key(reservation_id), "between_rounds") } == "1"
    end

    def steam_uid(event_player)
      return nil unless event_player&.steam_id

      convert_steam_id(event_player.steam_id)
    end

    def convert_steam_id(steam_id)
      return nil if steam_id.blank? || steam_id.in?(%w[Console BOT])

      SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
    rescue SteamCondenser::Error
      nil
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

    def parse_event(line)
      TF2LineParser::Parser.parse(line)
    rescue StandardError
      nil
    end

    def sanitize_line(line)
      cleaned = line.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      cleaned.gsub(ANSI_REGEX, "")
    rescue StandardError
      ""
    end

    def redis_key(reservation_id)
      "#{REDIS_PREFIX}:#{reservation_id}"
    end

    def build_stats_from_redis(data)
      players = {}
      scores = {}

      data.each do |field, value|
        case field
        when /\Aplayer:(\d+):(\w+)\z/
          uid = $1.to_i
          stat = $2
          players[uid] ||= { steam_uid: uid }
          players[uid][stat.to_sym] = stat.in?(%w[name team tf2_class]) ? value : value.to_i
        when /\Ascore:(\w+)\z/
          scores[$1] = value.to_i
        end
      end

      {
        players: players.values,
        scores: scores
      }
    end
  end
end
