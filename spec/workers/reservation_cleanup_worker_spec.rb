require 'spec_helper'

describe ReservationCleanupWorker do

  let(:old_reservation)   { create :reservation }
  let(:young_reservation) { create :reservation, :starts_at => Time.current }


  before do
    old_reservation.update_column(:ends_at, 25.days.ago)
  end

  it "finds the old reservations" do
    subject.old_reservations.to_a.should == [old_reservation]
  end

  it "deletes the logs and zip of old reservations" do
    Dir.should_receive(:exists?).with(Rails.root.join("server_logs", "#{old_reservation.id}")).and_return(true)
    FileUtils.should_receive(:rm_rf).with([Rails.root.join("server_logs", "#{old_reservation.id}"), Rails.root.join("public", "uploads", "#{old_reservation.zipfile_name}")])
    ReservationCleanupWorker.perform_async
  end
end

