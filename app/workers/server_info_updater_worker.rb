class ServerInfoUpdaterWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 1

  def perform(server_id)
    server = Server.find(server_id)
    server_info = ServerInfo.new(server)
    begin
      server_info.status
      server_info.get_stats
    rescue
      Rails.logger.info "Couldn't update #{server.name}"
    end
  end
end
