# typed: false
# frozen_string_literal: true

class StacLogsDownloaderWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3

  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)
    StacLogsDownloader.new(reservation).download_and_process
  end
end
