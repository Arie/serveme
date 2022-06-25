# frozen_string_literal: true

module LogLineHelper
  def clean_log_line(line)
    line
      .gsub(ip_regex, '0.0.0.0')
      .gsub(rcon_password_regex, 'rcon_password "*****"')
      .gsub(sv_password_regex, 'sv_password "*****"')
      .gsub(tv_password_regex, 'tv_password "*****"')
      .gsub(tftrue_logs_tf_api_key_regex, 'tftrue_logs_apikey "*****"')
      .gsub(logs_tf_api_key_regex, 'logstf_apikey "*****"')
      .gsub(sm_demostf_apikey_regex, 'sm_demostf_apikey "*****"')
      .gsub(logaddress_regex, 'logaddress_add "*****"')
      .gsub(logsecret_regex, 'sv_logsecret *****"')
  end

  def interesting_line?(log_line)
    interesting_event?(log_line) || map_start?(log_line)
  end

  private

  def map_start?(log_line)
    log_line.match(LogWorker::MAP_START)
  end

  def interesting_event?(log_line)
    interesting_events.any? { |event_type| log_line.match(event_type.regex) }
  end

  def interesting_events
    @interesting_events ||= [
      TF2LineParser::Events::Kill,
      TF2LineParser::Events::PointCapture,
      TF2LineParser::Events::RconCommand,
      TF2LineParser::Events::ConsoleSay,
      TF2LineParser::Events::Say,
      TF2LineParser::Events::Suicide,
      TF2LineParser::Events::RoundWin,
      TF2LineParser::Events::CurrentScore,
      TF2LineParser::Events::RoundStart,
      TF2LineParser::Events::Connect,
      TF2LineParser::Events::Disconnect,
      TF2LineParser::Events::MatchEnd,
      TF2LineParser::Events::FinalScore,
      TF2LineParser::Events::RoundStalemate
    ]
  end

  def ip_regex
    @ip_regex ||= /(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/
  end

  def rcon_password_regex
    @rcon_password_regex ||= /rcon_password "\S+"/
  end

  def sv_password_regex
    @sv_password_regex ||= /sv_password "\S+"/
  end

  def tv_password_regex
    @tv_password_regex ||= /tv_password "\S+"/
  end

  def tftrue_logs_tf_api_key_regex
    @tftrue_logs_tf_api_key_regex ||= /tftrue_logs_apikey "\S+"/
  end

  def logs_tf_api_key_regex
    @logs_tf_api_key_regex ||= /logstf_apikey "\S+"/
  end

  def sm_demostf_apikey_regex
    @sm_demostf_apikey_regex ||= /sm_demostf_apikey "\S+"/
  end

  def logaddress_regex
    @logaddress_regex ||= /logaddress_add \S+"/
  end

  def logsecret_regex
    @logsecret_regex ||= /sv_logsecret \S+"/
  end
end
