# frozen_string_literal: true

require 'spec_helper'

describe CleanupWorker do
  let!(:old_reservation)         { create :reservation }
  let!(:old_player_statistic)    { create :player_statistic, created_at: 40.days.ago }
  let!(:old_server_statistic)    { create :server_statistic, created_at: 40.days.ago }
  let!(:young_reservation)       { create :reservation, starts_at: Time.current }
  let!(:young_user)              { create :user, api_key: nil, created_at: 1.day.ago }
  let!(:old_user)                { create :user, api_key: nil, created_at: 8.days.ago }

  before do
    old_reservation.update_column(:ends_at, 32.days.ago)
  end

  it 'finds the old reservations' do
    subject.old_reservations.to_a.should == [old_reservation]
  end

  it 'finds the old player stats' do
    subject.old_player_statistics.to_a.should == [old_player_statistic]
  end

  it 'finds the old server stats' do
    subject.old_server_statistics.to_a.should == [old_server_statistic]
  end

  it 'deletes the logs and zip of old reservations and removes server/player stats' do
    described_class.perform_async

    PlayerStatistic.count.should == 0
    ServerStatistic.count.should == 0
  end

  it 'deactivates Gameye server that are still active' do
    create :server, active: true, type: 'GameyeServer'
    expect(GameyeServer.active.size).to eql 1

    described_class.perform_async

    expect(GameyeServer.active.size).to eql 0
  end

  it 'gives API keys to week old users' do
    described_class.perform_async

    expect(old_user.reload.api_key).to be_present
    expect(young_user.reload.api_key).not_to be_present
  end
end
