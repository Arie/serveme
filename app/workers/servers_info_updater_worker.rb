class ServersInfoUpdaterWorker
  include Sidekiq::Worker

  def perform
    Reservation.current.pluck(:server_id).each do |id|
      ServerInfoUpdaterWorker.perform_async(id)
    end
    GC.start
  end
end
