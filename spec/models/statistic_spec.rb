require 'spec_helper'

describe Statistic do

  describe '.top_10_users' do

    it "returns a hash with top users" do
      top_user    = create :user, :name => "Top user"
      top_user.stub(:donator? => true)
      other_user  = create :user, :name => "Not top user"

      create :reservation, :user => top_user, :starts_at => 10.minutes.ago, :ends_at => 1.hour.from_now
      create :reservation, :user => top_user, :starts_at => 24.hours.from_now, :ends_at => 25.hours.from_now
      create :reservation, :user => other_user

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
      user_1 = create :user
      user_1.stub(:donator? => true)
      user_2 = create :user
      user_2.stub(:donator? => true)
      user_3 = create :user
      user_3.stub(:donator? => true)

      3.times do |i|
        starts_at = i.days.from_now
        create :reservation, :server => server1, :starts_at => starts_at, :ends_at => starts_at + 1.hour, :user => user_1
      end
      2.times do |i|
        starts_at = i.days.from_now
        create :reservation, :server => server2, :starts_at => starts_at, :ends_at => starts_at + 1.hour, :user => user_2
      end
      1.times do |i|
        starts_at = i.days.from_now
        create :reservation, :server => server3, :starts_at => starts_at, :ends_at => starts_at + 1.hour, :user => user_3
      end

      top_10_hash = Statistic.top_10_servers

      top_10_hash.should eql "#1" => 3, "#2" => 2, "#3" => 1
    end
  end

  describe '.top_10_maps' do

    it "returns a hash with 10 most reserved maps" do
      user_1 = create :user
      user_1.stub(:donator? => true)

      2.times do |i|
        starts_at = i.days.from_now
        create :reservation, :map => 'ctf_meh', :starts_at => starts_at, :ends_at => starts_at + 1.hour, :user => user_1
      end
      1.times do |i|
        starts_at = i.days.from_now
        create :reservation, :map => 'pl_favorite', :starts_at => starts_at, :ends_at => starts_at + 1.hour, :user => user_1
      end
      3.times do |i|
        starts_at = i.days.from_now
        create :reservation, :map => 'ctf_pure_cancer', :starts_at => starts_at, :ends_at => starts_at + 1.hour, :user => user_1
      end

      top_10_hash = Statistic.top_10_maps

      top_10_hash.should eql 'ctf_pure_cancer' => 3, 'ctf_meh' => 2, 'pl_favorite' => 1
    end
  end

  describe '.reservations_per_day' do

    let(:today) {Date.today}
    let(:tomorrow) {Date.today + 1.day}
    before do
      Rails.cache.clear
      User.any_instance.stub(:donator? => true)
      create :reservation, :starts_at => tomorrow + 13.hour, :ends_at => tomorrow + 14.hours
      create :reservation, :starts_at => tomorrow + 15.hour, :ends_at => tomorrow + 16.hours
      create :reservation, :starts_at => tomorrow + 17.hour, :ends_at => tomorrow + 18.hours
    end

    it 'returns an array with reservations per date' do
      Statistic.reservations_per_day.should == [[(tomorrow).to_date.to_s, 3]]
    end
  end

  describe 'interesting_numbers' do

    it "returns the number of reservations" do
      reservation =  create :reservation
      Statistic.total_reservations.should == 1
    end

    it "returns total number playtime" do
      reservation =  create :reservation, :starts_at => 1.hours.from_now, :ends_at => 2.hours.from_now
      Statistic.total_playtime_seconds.should == 3600
      donator = create :user
      donator.stub(:donator? => true)
      reservation =  create :reservation, :starts_at => 3.hours.from_now, :ends_at => 4.hours.from_now, :user => donator
      Statistic.total_playtime_seconds.should == 7200
    end

  end

end
