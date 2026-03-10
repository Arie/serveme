# typed: false
# frozen_string_literal: true

class StacLogsDownloaderWorker
  include Sidekiq::Worker

  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)
    StacLogsDownloader.new(reservation).download_and_process
  end
end
