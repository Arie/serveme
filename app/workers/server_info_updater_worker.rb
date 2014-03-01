class ServerInfoUpdaterWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 1

  def perform(server_id)
    server = Server.find(server_id)
    server_info = ServerInfo.new(server)
    server_info.status
    server_info.get_stats
  end
end
