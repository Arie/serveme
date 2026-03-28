# typed: false
# frozen_string_literal: true

class LiveMatchStats
  REDIS_PREFIX = "live_match"
  EXPIRY = 12.hours.to_i

  ANSI_REGEX = /\e\[\d*;?\d*m\[?K?/
  MAP_START_REGEX = /Started map "/

  class << self
    # Process a single raw log line (used by rebuild and standalone callers)
    def process_line(reservation_id, raw_line)
      line = sanitize_line(raw_line)

      if line.match?(MAP_START_REGEX)
        reset_current_match(reservation_id)
        return
      end

      event = parse_event(line)
      return unless event

      process_events(reservation_id, [ event ])
    end

    # Process a batch of pre-parsed events, reading between_matches/between_rounds
    # once instead of per-event
    def process_events(reservation_id, events)
      between_matches = between_matches?(reservation_id)
      between_rounds = between_rounds?(reservation_id)

      events.each do |event|
        next unless event

        if event.is_a?(TF2LineParser::Events::Unknown) && event.unknown&.match?(MAP_START_REGEX)
          reset_current_match(reservation_id)
          between_matches = false
          between_rounds = false
          next
        end

        case event
        when TF2LineParser::Events::RoundStart, TF2LineParser::Events::MiniRoundStart
          set_field(reservation_id, "between_matches", "0")
          set_field(reservation_id, "between_rounds", "0")
          between_matches = false
          between_rounds = false
        when TF2LineParser::Events::MatchEnd
          finalize_current_match(reservation_id)
          set_field(reservation_id, "between_matches", "1")
          between_matches = true
        when TF2LineParser::Events::RoundLength, TF2LineParser::Events::MiniRoundLength
          accumulate_round_length(reservation_id, event.length.to_f) if event.length
        when TF2LineParser::Events::RoundWin, TF2LineParser::Events::MiniRoundWin
          set_field(reservation_id, "between_rounds", "1")
          between_rounds = true
          increment_team_score(reservation_id, event.team) if event.team
        when TF2LineParser::Events::FinalScore
          set_score(reservation_id, event.team, event.score.to_i) if event.team
        when TF2LineParser::Events::CurrentScore
          set_score(reservation_id, event.team, event.score.to_i) if event.team
        else
          next if between_matches || between_rounds

          process_player_event(reservation_id, event)
        end
      end
    end

    def get_stats(reservation_id)
      key = redis_key(reservation_id)

      Sidekiq.redis do |r|
        data = r.hgetall(key)
        return nil if data.empty?

        match_count = (data["match_count"] || "0").to_i
        matches = []

        # Load completed matches
        match_count.times do |i|
          completed_data = r.hgetall("#{key}:completed:#{i + 1}")
          next if completed_data.empty?

          matches << build_stats_from_redis(completed_data)
        end

        # Current in-progress match
        current = build_stats_from_redis(data)
        matches << current if current[:players].any? || current[:scores].any?

        matches.presence
      end
    end

    def rebuild(reservation_id, filepath)
      clear(reservation_id)
      return unless File.exist?(filepath)

      File.open(filepath, "r") do |f|
        f.each_line { |line| process_line(reservation_id, line) }
      end
    end

    def clear(reservation_id)
      key = redis_key(reservation_id)
      Sidekiq.redis do |r|
        match_count = (r.hget(key, "match_count") || "0").to_i
        keys_to_delete = [ key ]
        match_count.times { |i| keys_to_delete << "#{key}:completed:#{i + 1}" }
        r.del(*keys_to_delete)
      end
    end

    def exists?(reservation_id)
      Sidekiq.redis { |r| r.exists(redis_key(reservation_id)) > 0 }
    end

    private

    def reset_current_match(reservation_id)
      key = redis_key(reservation_id)
      Sidekiq.redis do |r|
        data = r.hgetall(key)
        fields_to_delete = data.keys.select do |field|
          field.start_with?("player:", "score:") || field.in?(%w[total_duration_cs between_matches between_rounds])
        end
        r.hdel(key, *fields_to_delete) if fields_to_delete.any?
      end
    end

    def finalize_current_match(reservation_id)
      key = redis_key(reservation_id)

      Sidekiq.redis do |r|
        match_num = r.hincrby(key, "match_count", 1)
        completed_key = "#{key}:completed:#{match_num}"

        data = r.hgetall(key)
        match_fields = {}
        delete_fields = []

        data.each do |field, value|
          if field.start_with?("player:") || field.start_with?("score:") || field == "total_duration_cs"
            match_fields[field] = value
            delete_fields << field
          end
        end

        return if match_fields.empty?

        r.pipelined do |p|
          match_fields.each { |f, v| p.hset(completed_key, f, v) }
          p.expire(completed_key, EXPIRY)
          p.hdel(key, *delete_fields)
        end
      end
    end

    def process_player_event(reservation_id, event)
      ops = []

      case event
      when TF2LineParser::Events::Kill
        collect_kill(ops, event)
      when TF2LineParser::Events::Airshot
        collect_airshot(ops, event)
        collect_damage(ops, event)
      when TF2LineParser::Events::Damage
        collect_damage(ops, event)
      when TF2LineParser::Events::Assist
        collect_assist(ops, event)
      when TF2LineParser::Events::Heal
        collect_heal(ops, event)
      when TF2LineParser::Events::Spawn
        collect_spawn(ops, event)
      when TF2LineParser::Events::RoleChange
        collect_spawn(ops, event)
      when TF2LineParser::Events::ChargeDeployed
        collect_uber(ops, event)
      when TF2LineParser::Events::MedicDeath
        collect_medic_death(ops, event)
      when TF2LineParser::Events::PointCapture
        collect_point_capture(ops, event)
      when TF2LineParser::Events::Suicide
        collect_suicide(ops, event)
      end

      flush_ops(reservation_id, ops) if ops.any?
    end

    def flush_ops(reservation_id, ops)
      key = redis_key(reservation_id)
      Sidekiq.redis do |r|
        r.pipelined do |p|
          ops.each do |op|
            case op[:type]
            when :incr
              p.hincrby(key, op[:field], op[:amount])
            when :set
              p.hset(key, op[:field], op[:value])
            end
          end
          p.expire(key, EXPIRY)
        end
      end
    end

    def collect_kill(ops, event)
      attacker_uid = steam_uid(event.player)
      target_uid = steam_uid(event.target)
      return unless attacker_uid && target_uid

      ops << { type: :incr, field: "player:#{attacker_uid}:kills", amount: 1 }
      ops << { type: :incr, field: "player:#{target_uid}:deaths", amount: 1 }
      collect_player_info(ops, attacker_uid, event.player)
      collect_player_info(ops, target_uid, event.target)
    end

    def collect_damage(ops, event)
      uid = steam_uid(event.player)
      target_uid = steam_uid(event.target)
      dmg = event.damage || 0

      if uid
        ops << { type: :incr, field: "player:#{uid}:damage", amount: dmg }
        collect_player_info(ops, uid, event.player)
      end

      if target_uid
        ops << { type: :incr, field: "player:#{target_uid}:damage_taken", amount: dmg }
        collect_player_info(ops, target_uid, event.target)
      end
    end

    def collect_assist(ops, event)
      uid = steam_uid(event.player)
      return unless uid

      ops << { type: :incr, field: "player:#{uid}:assists", amount: 1 }
      collect_player_info(ops, uid, event.player)
    end

    def collect_heal(ops, event)
      heals = event.healing || event.value || 0
      uid = steam_uid(event.player)
      target_uid = steam_uid(event.target)

      if uid
        ops << { type: :incr, field: "player:#{uid}:healing", amount: heals }
        collect_player_info(ops, uid, event.player)
      end

      if target_uid
        ops << { type: :incr, field: "player:#{target_uid}:heals_received", amount: heals }
        collect_player_info(ops, target_uid, event.target)
      end
    end

    def collect_spawn(ops, event)
      uid = steam_uid(event.player)
      return unless uid

      role = normalize_class(event.role)
      ops << { type: :set, field: "player:#{uid}:tf2_class", value: role }
      collect_player_info(ops, uid, event.player)
    end

    def collect_uber(ops, event)
      uid = steam_uid(event.player)
      return unless uid

      ops << { type: :incr, field: "player:#{uid}:ubers", amount: 1 }
      collect_player_info(ops, uid, event.player)
    end

    def collect_medic_death(ops, event)
      uid = steam_uid(event.target)
      return unless uid

      ops << { type: :incr, field: "player:#{uid}:drops", amount: 1 } if event.ubercharge
      collect_player_info(ops, uid, event.target)
    end

    def collect_airshot(ops, event)
      uid = steam_uid(event.player)
      return unless uid

      ops << { type: :incr, field: "player:#{uid}:airshots", amount: 1 }
      collect_player_info(ops, uid, event.player)
    end

    def collect_point_capture(ops, event)
      event.cappers.each do |capper|
        uid = convert_steam_id(capper.steam_id)
        next unless uid

        ops << { type: :incr, field: "player:#{uid}:caps", amount: 1 }
      end
    end

    def collect_suicide(ops, event)
      uid = steam_uid(event.player)
      return unless uid

      ops << { type: :incr, field: "player:#{uid}:deaths", amount: 1 }
      collect_player_info(ops, uid, event.player)
    end

    def collect_player_info(ops, uid, event_player)
      name = event_player.name
      team = event_player.team

      ops << { type: :set, field: "player:#{uid}:name", value: name } if name
      ops << { type: :set, field: "player:#{uid}:team", value: team } if team.present? && team.in?(%w[Red Blue])
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

    def accumulate_round_length(reservation_id, length)
      key = redis_key(reservation_id)
      # Store as integer centiseconds to use HINCRBY, then convert back
      centiseconds = (length * 100).round
      Sidekiq.redis { |r| r.hincrby(key, "total_duration_cs", centiseconds) }
    end

    def between_matches?(reservation_id)
      Sidekiq.redis { |r| r.hget(redis_key(reservation_id), "between_matches") } == "1"
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
      total_duration_cs = 0

      data.each do |field, value|
        case field
        when /\Aplayer:(\d+):(\w+)\z/
          uid = $1.to_i
          stat = $2
          players[uid] ||= { steam_uid: uid }
          players[uid][stat.to_sym] = stat.in?(%w[name team tf2_class]) ? value : value.to_i
        when /\Ascore:(\w+)\z/
          scores[$1] = value.to_i
        when "total_duration_cs"
          total_duration_cs = value.to_i
        end
      end

      {
        players: players.values,
        scores: scores,
        total_duration_seconds: total_duration_cs / 100.0
      }
    end
  end
end
