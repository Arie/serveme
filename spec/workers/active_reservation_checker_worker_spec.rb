require 'spec_helper'

describe ActiveReservationCheckerWorker do

  let(:reservation) { create :reservation }

  it "loops over the reservations and sends them for checking" do
    ServerNumberOfPlayersWorker.should_receive(:perform_async).with(reservation.id)
    ActiveReservationCheckerWorker.perform_async(Reservation.all.map(&:id))
  end

end
