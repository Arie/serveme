# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Statistic do
  describe '.top_10_users' do
    it 'returns a hash with top users' do
      top_user = create :user, name: 'Top user'
      allow(top_user).to receive(:donator?).and_return(true)
      other_user = create :user, name: 'Not top user'

      create :reservation, user: top_user, starts_at: 10.minutes.ago, ends_at: 1.hour.from_now
      create :reservation, user: top_user, starts_at: 24.hours.from_now, ends_at: 25.hours.from_now
      create :reservation, user: other_user

      Rails.cache.clear  # Clear cache to ensure clean state
      top_10_hash = Statistic.top_10_users
      top_10_hash[top_user].should eql 2
      top_10_hash[other_user].should eql 1
    end
  end

  describe '.top_10_servers' do
    it 'returns a hash with top servers' do
      server1 = create :server, name: '#1'
      server2 = create :server, name: '#2'
      server3 = create :server, name: '#3'

      user_1 = create :user
      allow(user_1).to receive(:donator?).and_return(true)

      user_2 = create :user
      allow(user_2).to receive(:donator?).and_return(true)

      user_3 = create :user
      allow(user_3).to receive(:donator?).and_return(true)

      3.times do |i|
        starts_at = i.days.from_now
        create :reservation, server: server1, starts_at: starts_at, ends_at: starts_at + 1.hour, user: user_1
      end
      2.times do |i|
        starts_at = i.days.from_now
        create :reservation, server: server2, starts_at: starts_at, ends_at: starts_at + 1.hour, user: user_2
      end
      starts_at = 1.days.from_now
      create :reservation, server: server3, starts_at: starts_at, ends_at: starts_at + 1.hour, user: user_3

      top_10_hash = Statistic.top_10_servers

      top_10_hash.should eql '#1' => 3, '#2' => 2, '#3' => 1
    end
  end

  describe '.reservations_per_day' do
    let(:today) { Date.today }
    let(:tomorrow) { Date.today + 1.day }

    it 'returns an array with reservations per date' do
      allow_any_instance_of(User).to receive(:donator?).and_return(true)

      create :reservation, starts_at: tomorrow + 13.hour, ends_at: tomorrow + 14.hours
      create :reservation, starts_at: tomorrow + 15.hour, ends_at: tomorrow + 16.hours
      create :reservation, starts_at: tomorrow + 17.hour, ends_at: tomorrow + 18.hours

      Rails.cache.delete('reservations_per_day')  # Clear only the specific cache key
      stats = Statistic.reservations_per_day
      count = stats.first.last
      count.should == 3
    end
  end

  describe 'interesting_numbers' do
    it 'returns the number of reservations' do
      reservation = create :reservation
      Statistic.total_reservations.should == 1
    end

    it 'returns total number playtime' do
      reservation = create :reservation, starts_at: 1.hours.from_now, ends_at: 2.hours.from_now
      Statistic.total_playtime_seconds.should == 3600
      donator = create :user
      donator.stub(donator?: true)
      reservation = create :reservation, starts_at: 3.hours.from_now, ends_at: 4.hours.from_now, user: donator
      Statistic.total_playtime_seconds.should == 7200
    end
  end
end
