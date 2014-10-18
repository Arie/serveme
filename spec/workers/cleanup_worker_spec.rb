require 'spec_helper'

describe CleanupWorker do

  let!(:old_reservation)         { create :reservation }
  let!(:old_player_statistic)    { create :player_statistic, created_at: 40.days.ago }
  let!(:old_server_statistic)    { create :server_statistic, created_at: 40.days.ago }
  let!(:young_reservation)       { create :reservation, :starts_at => Time.current }


  before do
    old_reservation.update_column(:ends_at, 32.days.ago)
  end

  it "finds the old reservations" do
    subject.old_reservations.to_a.should == [old_reservation]
  end

  it "finds the old player stats" do
    subject.old_player_statistics.to_a.should == [old_player_statistic]
  end

  it "finds the old server stats" do
    subject.old_server_statistics.to_a.should == [old_server_statistic]
  end

  it "deletes the logs and zip of old reservations and removes server/player stats" do
    Dir.should_receive(:exists?).with(Rails.root.join("server_logs", "#{old_reservation.id}")).and_return(true)
    FileUtils.should_receive(:rm_rf).with([Rails.root.join("server_logs", "#{old_reservation.id}"), Rails.root.join("public", "uploads", "#{old_reservation.zipfile_name}")])
    described_class.perform_async

    PlayerStatistic.count.should == 0
    ServerStatistic.count.should == 0
  end
end

