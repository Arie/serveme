class ServersInfoUpdaterWorker
  include Sidekiq::Worker

  def perform
    Server.active.each do |s|
      ServerInfoUpdaterWorker.perform_async(s.id)
    end
  end
end
