# frozen_string_literal: true

class InactiveServerCheckerWorker
  include Sidekiq::Worker

  attr_accessor :server

  sidekiq_options retry: 1

  def perform(server_id)
    @server = Server.find(server_id)

    return unless server.sdr?

    server_info = fetch_sdr_info
    save_sdr_info(server_info)
  end

  private

  def fetch_sdr_info
    server_info = server.server_info

    begin
      server_info.fetch_rcon_status
      server_info
    rescue SteamCondenser::Error, Errno::ECONNREFUSED
      Rails.logger.warn "Couldn't get RCON status of #{server.name} - #{server.ip}:#{server.port}"
      nil
    end
  end

  def save_sdr_info(server_info)
    return unless server_info&.ip.present?

    server.update_columns(
      last_sdr_ip: server_info.ip,
      last_sdr_port: server_info.port,
      last_sdr_tv_port: server_info.port + 1
    )
  end
end
