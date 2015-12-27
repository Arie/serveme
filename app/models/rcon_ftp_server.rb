# frozen_string_literal: true
class RconFtpServer < RemoteServer

  include FtpAccess

  def restart
    Rails.logger.info("Attempting RCON restart of server #{name}")
    rcon_exec("_restart")
  end

  def current_reservation
    reservations.where('reservations.starts_at <= ? AND reservations.ended = ?', Time.current, false).first
  end

end
