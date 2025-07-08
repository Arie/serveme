# typed: true
# frozen_string_literal: true

class RconFtpServer < RemoteServer
  include FtpAccess

  def restart
    Rails.logger.info("Attempting RCON restart of server #{name}")
    rcon_exec("_restart")
  end

  def current_reservation
    reservations.where(starts_at: ..Time.current).where(ended: false).first
  end
end
