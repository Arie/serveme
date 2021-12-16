# frozen_string_literal: true

module LogLineHelper
  def clean_log_line(line)
    line
      .gsub(ip_regex, '0.0.0.0')
      .gsub(rcon_password_regex, 'rcon_password "*****"')
      .gsub(sv_password_regex, 'sv_password "*****"')
      .gsub(tv_password_regex, 'tv_password "*****"')
      .gsub(logs_tf_api_key_regex, 'tftrue_logs_apikey "*****"')
      .gsub(sm_demostf_apikey_regex, 'sm_demostf_apikey "*****"')
      .gsub(logaddress_regex, 'logaddress_add "*****"')
      .gsub(logsecret_regex, 'sv_logsecret *****"')
  end

  private

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

  def logs_tf_api_key_regex
    @logs_tf_api_key_regex ||= /tftrue_logs_apikey "\S+"/
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
