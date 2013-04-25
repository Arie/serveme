require 'spec_helper'

describe User do

  describe "#steam_profile_url" do

    it "creates a steam profile url based on the uid" do
      subject.stub(:uid => '123')
      subject.steam_profile_url.should eql "http://steamcommunity.com/profiles/123"
    end

  end

  describe '.find_for_steam_auth' do

    before do
      @auth = stub(:provider => 'steam',
                :uid      => '321',
                :info     => stub(:name => "Kees", :nickname => "Killer")
              )
    end

    it "creates and returns a new user if it can't find an existing one" do
      expect{User.find_for_steam_auth(@auth)}.to change{User.count}.from(0).to(1)
    end

    it "returns an existing user if it could find one by uid" do
      create(:user, :uid => '321')
      expect{User.find_for_steam_auth(@auth)}.not_to change{User.count}
    end

    it "updates an existing user with new information" do
      user = create(:user, :name => "Karel", :uid => '321')
      expect{User.find_for_steam_auth(@auth)}.not_to change{User.count}
      user.reload.name.should eql "Kees"
    end
  end

  describe "#total_reservation_seconds" do
    it "calculates the amount of time a user has reserved servers" do
      user = create(:user)
      create(:reservation, :user => user, :starts_at => 1.hour.from_now, :ends_at => 2.hours.from_now)
      user.total_reservation_seconds.should == 3600
    end
  end

  describe '#top10?' do

    it 'returns if a user is in the top 10' do
      user = create(:user)
      create(:reservation, :user => user)
      user.should be_top10
    end

  end

end
