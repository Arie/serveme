# frozen_string_literal: true

module LogLineHelper
  def clean_log_line(line)
    line
      .gsub(ip_regex, '0.0.0.0')
      .gsub(logs_tf_api_key_regex, 'tftrue_logs_apikey "logs_api_key"')
      .gsub(sm_demostf_apikey_regex, 'sm_demostf_apikey "demos_api_key"')
      .gsub(logaddress_regex, 'logaddress_add "logaddress"')
      .gsub(logsecret_regex, 'sv_logsecret logsecret"')
  end

  private

  def ip_regex
    @ip_regex ||= /(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/
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
