# frozen_string_literal: true

class InactiveServerCheckerWorker
  include Sidekiq::Worker

  attr_accessor :server

  sidekiq_options retry: 1

  def perform(server_id, latest_version)
    @server = Server.find(server_id)
    @latest_version = latest_version

    server_info = fetch_sdr_info
    save_version_info(server_info)
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

  def save_version_info(server_info)
    return unless server_info&.version.present?

    Rails.logger.warn("Server #{server.name} was updating since #{I18n.l(server.update_started_at, format: :short)} but is now back online with old version #{server_info.version} instead of latest #{@latest_version}") if server.update_status == 'Updating' && server_info.version < @latest_version

    server.update_columns(
      update_status: nil,
      last_known_version: server_info.version
    )
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
