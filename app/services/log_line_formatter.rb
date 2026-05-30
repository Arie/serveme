# typed: true
# frozen_string_literal: true

class LogLineFormatter
  extend T::Sig

  TIMESTAMP_REGEX = /^L (\d{2}\/\d{2}\/\d{4} - \d{2}:\d{2}:\d{2}):/

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

  EVENT_TYPE_MAP = {
    TF2LineParser::Events::Kill => :kill,
    TF2LineParser::Events::Say => :say,
    TF2LineParser::Events::TeamSay => :team_say,
    TF2LineParser::Events::Connect => :connect,
    TF2LineParser::Events::Disconnect => :disconnect,
    TF2LineParser::Events::PointCapture => :point_capture,
    TF2LineParser::Events::CaptureBlock => :capture_block,
    TF2LineParser::Events::RoundWin => :round_win,
    TF2LineParser::Events::RoundStart => :round_start,
    TF2LineParser::Events::RoundStalemate => :round_stalemate,
    TF2LineParser::Events::RoundLength => :round_length,
    TF2LineParser::Events::CurrentScore => :current_score,
    TF2LineParser::Events::FinalScore => :final_score,
    TF2LineParser::Events::MatchEnd => :match_end,
    TF2LineParser::Events::RconCommand => :rcon,
    TF2LineParser::Events::ConsoleSay => :console_say,
    TF2LineParser::Events::Suicide => :suicide,
    TF2LineParser::Events::RoleChange => :role_change,
    TF2LineParser::Events::Spawn => :spawn,
    TF2LineParser::Events::Domination => :domination,
    TF2LineParser::Events::Revenge => :revenge,
    TF2LineParser::Events::PickupItem => :pickup_item,
    TF2LineParser::Events::AirshotHeal => :airshot_heal,
    TF2LineParser::Events::Heal => :heal,
    TF2LineParser::Events::ChargeDeployed => :charge_deployed,
    TF2LineParser::Events::ChargeReady => :charge_ready,
    TF2LineParser::Events::ChargeEnded => :charge_ended,
    TF2LineParser::Events::LostUberAdvantage => :lost_uber_advantage,
    TF2LineParser::Events::EmptyUber => :empty_uber,
    TF2LineParser::Events::FirstHealAfterSpawn => :first_heal_after_spawn,
    TF2LineParser::Events::PlayerExtinguished => :player_extinguished,
    TF2LineParser::Events::JoinedTeam => :joined_team,
    TF2LineParser::Events::BuiltObject => :builtobject,
    TF2LineParser::Events::Airshot => :airshot,
    TF2LineParser::Events::HeadshotDamage => :headshot_damage,
    TF2LineParser::Events::Damage => :damage,
    TF2LineParser::Events::MedicDeath => :medic_death,
    TF2LineParser::Events::MedicDeathEx => :medic_death_ex,
    TF2LineParser::Events::KilledObject => :killedobject,
    TF2LineParser::Events::ShotFired => :shot_fired,
    TF2LineParser::Events::ShotHit => :shot_hit,
    TF2LineParser::Events::Assist => :assist,
    TF2LineParser::Events::PositionReport => :position_report
  }.freeze

  # Memoization cache for Steam ID conversions (cleared per-request via middleware or manually)
  @steam_id_cache = {}
  class << self
    attr_accessor :steam_id_cache
  end

  attr_reader :line

  sig { params(line: String).void }
  def initialize(line)
    @line = line
  end

  sig { params(skip_sanitization: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
  def format(skip_sanitization: false)
    {
      timestamp: extract_timestamp,
      type: event_type,
      event: parsed_event,
      raw: skip_sanitization ? @line : self.class.sanitize_sensitive_data(@line),
      message: extract_message(skip_sanitization),
      admin: skip_sanitization
    }
  end

  sig { returns(Symbol) }
  def event_type
    event = parsed_event
    return :unknown if event.nil?

    EVENT_TYPE_MAP.each { |klass, type| return type if event.is_a?(klass) }
    :unknown
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

  sig { params(line: String).returns(String) }
  def self.sanitize_sensitive_data(line)
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

  sig { params(skip_sanitization: T::Boolean).returns(T.nilable(String)) }
  def extract_message(skip_sanitization)
    event = parsed_event
    return nil unless event&.respond_to?(:message)

    msg = event.message.to_s
    skip_sanitization ? msg : self.class.sanitize_sensitive_data(msg)
  end

  sig { params(line: String).returns(String) }
  def self.strip_timestamp(line)
    # Remove the "L MM/DD/YYYY - HH:MM:SS: " prefix
    line.sub(/^L \d{2}\/\d{2}\/\d{4} - \d{2}:\d{2}:\d{2}:\s*/, "")
  end
end
