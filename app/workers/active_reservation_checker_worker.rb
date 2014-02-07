class ActiveReservationCheckerWorker
  include Sidekiq::Worker

  def perform(reservation_ids)
    reservation_ids.each do |reservation_id|
      ServerNumberOfPlayersWorker.perform_async(reservation_id)
    end
  end
end
