class TragicServer < RconFtpServer

  def restart(rcon = current_rcon)
    begin
      fast_restart(rcon)
    rescue Exception => e
      Rails.logger.warn("Got error #{e.class}: #{e.message} trying to do a fast restart of server #{name}, falling back to slow restart")
      slow_restart
    end
  end

  def slow_restart
    Rails.logger.info("Attempting web control restart of server #{name}")
    web_management.restart
  end

  def web_management
    @web_management ||= NfoControlPanel.new(ip.split('.').first)
  end

end
