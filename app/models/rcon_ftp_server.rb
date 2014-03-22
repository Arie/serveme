class RconFtpServer < RemoteServer

  include FtpAccess

  def restart(rcon = current_rcon)
    Rails.logger.info("Attempting RCON restart of server #{name}")
    rcon_auth(rcon)
    rcon_exec("_restart")
  end

  def current_reservation
    reservations.where('reservations.starts_at <= ? AND reservations.ended = ?', Time.current, false).first
  end

end
