class ServerInfoUpdaterWorker
  include Sidekiq::Worker

  sidekiq_options :retry => false

  def perform(server_id)
    server      = Server.find(server_id)
    server_info = ServerInfo.new(server)
    begin
      server_info.status
      server_info.get_stats
      server_info.get_rcon_status
      ServerMetric.new(server_info)
      nil
    rescue
      Rails.logger.warn "Couldn't update #{server.name}"
    end
  end
end
