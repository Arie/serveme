# typed: true
# frozen_string_literal: true

class LogLineFormatter
  extend T::Sig

  TIMESTAMP_REGEX = /^L (\d{2}\/\d{2}\/\d{4} - \d{2}:\d{2}:\d{2}):/
  POSITION_REGEX = /\s*\((attacker_position|victim_position)\s+"[^"]+"\)/

  # Patterns for sanitizing sensitive data
  IP_REGEX = /(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/
  RCON_PASSWORD_REGEX = /rcon_password "\S+"/
  SV_PASSWORD_REGEX = /sv_password "\S+"/
  TV_PASSWORD_REGEX = /tv_password "\S+"/
  TFTRUE_LOGS_API_KEY_REGEX = /tftrue_logs_apikey "\S+"/
  LOGS_TF_API_KEY_REGEX = /logstf_apikey "\S+"/
  SM_DEMOSTF_APIKEY_REGEX = /sm_demostf_apikey "\S+"/
  LOGADDRESS_ADD_REGEX = /logaddress_add \S+"/
  LOGADDRESS_DEL_REGEX = /logaddress_del \S+"/
  LOGSECRET_REGEX = /sv_logsecret \S+/

  TF2_KILLICONS = YAML.load_file(Rails.root.join("config", "tf2_killicons.yml")).freeze

  # Memoization cache for Steam ID conversions (cleared per-request via middleware or manually)
  @steam_id_cache = {}
  class << self
    attr_accessor :steam_id_cache
  end

  attr_reader :line, :raw_line

  sig { params(line: String).void }
  def initialize(line)
    @raw_line = line
    @line = line  # Keep original line for parsing
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def format
    {
      timestamp: extract_timestamp,
      type: event_type,
      event: parsed_event,
      raw: sanitize_sensitive_data(@raw_line),
      clean: clean_for_display(@line)
    }
  end

  sig { returns(Symbol) }
  def event_type
    return :unknown if parsed_event.nil?

    case parsed_event
    when TF2LineParser::Events::Kill
      :kill
    when TF2LineParser::Events::Say
      :say
    when TF2LineParser::Events::TeamSay
      :team_say
    when TF2LineParser::Events::Connect
      :connect
    when TF2LineParser::Events::Disconnect
      :disconnect
    when TF2LineParser::Events::PointCapture
      :point_capture
    when TF2LineParser::Events::CaptureBlock
      :capture_block
    when TF2LineParser::Events::RoundWin
      :round_win
    when TF2LineParser::Events::RoundStart
      :round_start
    when TF2LineParser::Events::RoundStalemate
      :round_stalemate
    when TF2LineParser::Events::RoundLength
      :round_length
    when TF2LineParser::Events::CurrentScore
      :current_score
    when TF2LineParser::Events::FinalScore
      :final_score
    when TF2LineParser::Events::MatchEnd
      :match_end
    when TF2LineParser::Events::RconCommand
      :rcon
    when TF2LineParser::Events::ConsoleSay
      :console_say
    when TF2LineParser::Events::Suicide
      :suicide
    when TF2LineParser::Events::RoleChange
      :role_change
    when TF2LineParser::Events::Spawn
      :spawn
    when TF2LineParser::Events::Domination
      :domination
    when TF2LineParser::Events::Revenge
      :revenge
    when TF2LineParser::Events::PickupItem
      :pickup_item
    when TF2LineParser::Events::AirshotHeal
      :airshot_heal
    when TF2LineParser::Events::Heal
      :heal
    when TF2LineParser::Events::ChargeDeployed
      :charge_deployed
    when TF2LineParser::Events::ChargeReady
      :charge_ready
    when TF2LineParser::Events::ChargeEnded
      :charge_ended
    when TF2LineParser::Events::LostUberAdvantage
      :lost_uber_advantage
    when TF2LineParser::Events::EmptyUber
      :empty_uber
    when TF2LineParser::Events::FirstHealAfterSpawn
      :first_heal_after_spawn
    when TF2LineParser::Events::PlayerExtinguished
      :player_extinguished
    when TF2LineParser::Events::JoinedTeam
      :joined_team
    when TF2LineParser::Events::BuiltObject
      :builtobject
    when TF2LineParser::Events::Airshot
      :airshot
    when TF2LineParser::Events::HeadshotDamage
      :headshot_damage
    when TF2LineParser::Events::Damage
      :damage
    when TF2LineParser::Events::MedicDeath
      :medic_death
    when TF2LineParser::Events::MedicDeathEx
      :medic_death_ex
    when TF2LineParser::Events::KilledObject
      :killedobject
    when TF2LineParser::Events::ShotFired
      :shot_fired
    when TF2LineParser::Events::ShotHit
      :shot_hit
    when TF2LineParser::Events::Assist
      :assist
    when TF2LineParser::Events::PositionReport
      :position_report
    else
      :unknown
    end
  end

  # Returns [x, y, width, height, sprite] for killicon sprite, or nil if not found
  # sprite is 1, 2, or 3 (defaults to 1 if not specified)
  sig { params(weapon_name: T.nilable(String)).returns(T.nilable(T::Array[Integer])) }
  def self.killicon_sprite(weapon_name)
    return nil unless weapon_name

    coords = TF2_KILLICONS[weapon_name.downcase] || TF2_KILLICONS["default"]
    return nil unless coords

    # Ensure 5 elements: [x, y, w, h, sprite] - default sprite to 1
    coords.length == 5 ? coords : coords + [ 1 ]
  end

  sig { params(steam_id: String).returns(T.nilable(Integer)) }
  def self.steam_id_to_community_id(steam_id)
    return nil if steam_id.blank? || steam_id.in?(%w[Console BOT])

    # Use memoization cache to avoid repeated conversions for same player
    return steam_id_cache[steam_id] if steam_id_cache.key?(steam_id)

    steam_id_cache[steam_id] = SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
  rescue SteamCondenser::Error
    steam_id_cache[steam_id] = nil
  end

  sig { void }
  def self.clear_steam_id_cache!
    @steam_id_cache = {}
  end

  private

  sig { returns(T.nilable(Time)) }
  def extract_timestamp
    match = @line.match(TIMESTAMP_REGEX)
    return nil unless match

    Time.strptime(T.must(match[1]), "%m/%d/%Y - %H:%M:%S")
  rescue ArgumentError
    nil
  end

  sig { returns(T.nilable(TF2LineParser::Events::Event)) }
  def parsed_event
    @parsed_event ||= begin
      result = TF2LineParser::Parser.parse(@line)
      result.is_a?(TF2LineParser::Events::Event) ? result : nil
    rescue StandardError
      # Try to parse with a timestamp prefix for edge cases
      begin
        TF2LineParser::Parser.parse("L 01/01/2000 - 00:00:00: #{@line}")
      rescue StandardError
        nil
      end
    end
  end

  sig { params(line: String).returns(String) }
  def clean_for_display(line)
    # Remove position data from line for cleaner display
    line.gsub(POSITION_REGEX, "")
  end

  sig { params(line: String).returns(String) }
  def sanitize_sensitive_data(line)
    line
      .gsub(IP_REGEX, "0.0.0.0")
      .gsub(RCON_PASSWORD_REGEX, 'rcon_password "*****"')
      .gsub(SV_PASSWORD_REGEX, 'sv_password "*****"')
      .gsub(TV_PASSWORD_REGEX, 'tv_password "*****"')
      .gsub(TFTRUE_LOGS_API_KEY_REGEX, 'tftrue_logs_apikey "*****"')
      .gsub(LOGS_TF_API_KEY_REGEX, 'logstf_apikey "*****"')
      .gsub(SM_DEMOSTF_APIKEY_REGEX, 'sm_demostf_apikey "*****"')
      .gsub(LOGADDRESS_ADD_REGEX, 'logaddress_add "*****"')
      .gsub(LOGADDRESS_DEL_REGEX, 'logaddress_del "*****"')
      .gsub(LOGSECRET_REGEX, 'sv_logsecret "*****"')
  end

  sig { params(line: String).returns(String) }
  def self.strip_timestamp(line)
    # Remove the "L MM/DD/YYYY - HH:MM:SS: " prefix
    line.sub(/^L \d{2}\/\d{2}\/\d{4} - \d{2}:\d{2}:\d{2}:\s*/, "")
  end
end
