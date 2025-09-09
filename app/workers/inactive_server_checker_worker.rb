# typed: true
# frozen_string_literal: true

class InactiveServerCheckerWorker
  include Sidekiq::Worker

  attr_accessor :server

  sidekiq_options retry: 1

  def perform(server_id, latest_version)
    @server = Server.find(server_id)
    @latest_version = latest_version

    server_info = fetch_sdr_info
    server.save_version_info(server_info)
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
    return unless server_info&.ip.present? && server_info&.port.present?
    return if server_info.ip == server.last_sdr_ip && server_info.port == server.last_sdr_port

    server.update_columns(
      last_sdr_ip: server_info.ip,
      last_sdr_port: server_info.port,
      last_sdr_tv_port: server_info.port + 1
    )
  end
end
