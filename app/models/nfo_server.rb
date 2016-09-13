# frozen_string_literal: true
class NfoServer < RemoteServer

  include FtpAccess

  def restart
    retryable do
      Rails.logger.info("Attempting web control restart of server #{name}")
      web_management.restart
    end
  end

  def web_management
    @web_management ||= NfoControlPanel.new(ip.split('.').first)
  end

  def retryable(tries = 0)
    tries += 1
    yield
  rescue Exception => e
    if tries < 5
      Rails.logger.warn "Restarting server #{name} failed: #{e}, retrying in 1 second"
      sleep 1
      retry
    else
      Rails.logger.warn "Restarting server #{name} failed: #{e}, retries exhausted"
      raise
    end
  end

end
