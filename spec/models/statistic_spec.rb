require 'spec_helper'

describe Statistic do

  describe '.top_10_users' do

    it "returns a hash with top users" do
      top_user    = create :user, :name => "Top user"
      other_user  = create :user, :name => "Not top user"

      create :reservation, :user => top_user, :starts_at => 10.minutes.ago, :ends_at => 1.hour.from_now
      create :reservation, :user => top_user, :starts_at => 24.hours.from_now, :ends_at => 25.hours.from_now
      Version.update_all(:whodunnit => top_user.id)
      create :reservation, :user => other_user
      Version.last.update_attributes(:whodunnit => other_user.id)

      top_10_hash = Statistic.top_10_users
      top_10_hash[top_user].should eql 2
      top_10_hash[other_user].should eql 1
    end
  end

  describe '.top_10_servers' do

    it "returns a hash with top servers" do
      server1 = create :server, :name => "#1"
      server2 = create :server, :name => "#2"
      server3 = create :server, :name => "#3"

      3.times do |i|
        starts_at = i.days.from_now
        create :reservation, :server => server1, :starts_at => starts_at, :ends_at => starts_at + 1.hour
      end
      2.times do |i|
        starts_at = i.days.from_now
        create :reservation, :server => server2, :starts_at => starts_at, :ends_at => starts_at + 1.hour
      end
      1.times do |i|
        starts_at = i.days.from_now
        create :reservation, :server => server3, :starts_at => starts_at, :ends_at => starts_at + 1.hour
      end

      top_10_hash = Statistic.top_10_servers

      top_10_hash.should eql "#1" => 3, "#2" => 2, "#3" => 1
    end
  end

  describe 'interesting_numbers' do

    it "returns the number of reservations" do
      reservation =  create :reservation
      Statistic.total_reservations.should == reservation.id
    end

    it "returns total number playtime" do
      reservation =  create :reservation, :starts_at => 1.hours.from_now, :ends_at => 2.hours.from_now
      Statistic.total_playtime_seconds.should == 3600
      reservation =  create :reservation, :starts_at => 3.hours.from_now, :ends_at => 4.hours.from_now
      Statistic.total_playtime_seconds.should == 7200
    end

  end

end
