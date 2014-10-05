class NfoServer < RemoteServer

  include FtpAccess

  def restart
    Rails.logger.info("Attempting web control restart of server #{name}")
    web_management.restart
  end

  def web_management
    @web_management ||= NfoControlPanel.new(ip.split('.').first)
  end

end
