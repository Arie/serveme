# typed: true
# frozen_string_literal: true

class RconFtpServer < RemoteServer
  extend T::Sig
  include FtpAccess

  sig { returns(T.nilable(T.any(String, T::Boolean))) }
  def restart
    Rails.logger.info("Attempting RCON restart of server #{name}")
    result = rcon_exec("_restart")
    result.is_a?(String) ? result : true
  end

  sig { returns(T.nilable(Reservation)) }
  def current_reservation
    reservations.where(starts_at: ..Time.current).where(ended: false).first
  end
end
