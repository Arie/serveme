class ServersInfoUpdaterWorker
  include Sidekiq::Worker

  def perform
    Server.active.pluck(:id).each do |id|
      ServerInfoUpdaterWorker.perform_async(id)
    end
    GC.start
  end
end
