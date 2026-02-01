# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe CleanupWorker do
  let(:old_reservation)         { create :reservation, :old }
  let(:old_player_statistic)    { create :player_statistic, created_at: 40.days.ago }
  let(:old_server_statistic)    { create :server_statistic, created_at: 40.days.ago }
  let(:young_reservation)       { create :reservation, starts_at: Time.current }
  let(:young_user)              { create :user, api_key: nil, created_at: 1.day.ago }
  let(:old_user)                { create :user, api_key: nil, created_at: 8.days.ago }

  before do
    allow_any_instance_of(described_class).to receive(:remove_old_reservation_logs_and_zips)
  end

  it 'finds the old reservations' do
    old_reservation
    subject.old_reservations.to_a.should == [ old_reservation ]
  end

  it 'finds the old player stats' do
    old_player_statistic
    subject.old_player_statistics.to_a.should == [ old_player_statistic ]
  end

  it 'finds the old server stats' do
    old_server_statistic
    subject.old_server_statistics.to_a.should == [ old_server_statistic ]
  end

  it 'deletes the logs and zip of old reservations and removes server/player stats' do
    old_player_statistic
    old_server_statistic
    described_class.perform_async

    expect(PlayerStatistic.count).to eql 0
    expect(ServerStatistic.count).to eql 0
  end

  it 'gives API keys to week old users' do
    young_user
    old_user
    described_class.perform_async

    expect(old_user.reload.api_key).to be_present
    expect(young_user.reload.api_key).not_to be_present
  end
end
