require 'spec_helper'

describe CronWorker do

  let(:reservation) { create :reservation }

  before do
    condenser = double.as_null_object
    server = double(:server, :id => 1, :rcon_auth => true, :rcon_disconnect => true, :condenser => condenser)
    reservation.stub(:server => server)
    allow(ServerMetric).to receive(:new)
  end

  describe "#end_past_reservations" do

    it "tells unended past reservations to end" do
      reservation.update_column(:ends_at, 1.minute.ago)
      reservation.update_column(:provisioned, true)
      ReservationWorker.should_receive(:perform_async).with(reservation.id, "end")
      CronWorker.perform_async
    end

  end

  describe "#start_active_reservations" do

    it "tells unstarted active reservations to start" do
      reservation.update_column(:starts_at, 1.minute.ago)
      reservation.update_column(:provisioned, false)
      ReservationWorker.should_receive(:perform_async).with(reservation.id, "start")
      CronWorker.perform_async
    end

  end

  describe "#check_active_reservations" do

    it "triggers the active reservation checker worker for active reservations" do
      reservation.update_attribute(:provisioned, true)
      reservation.update_attribute(:ended,       false)
      ActiveReservationsCheckerWorker.should_receive(:perform_async).with([reservation.id])
      CronWorker.perform_async
    end

  end

end
