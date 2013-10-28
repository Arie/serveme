# encoding: UTF-8
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
      @auth = double(:provider => 'steam',
                :uid      => '321',
                :info     => double(:name => "Kees", :nickname => "Killer")
              )
    end

    context 'new user' do

      it "creates and returns a new user if it can't find an existing one" do
        expect{User.find_for_steam_auth(@auth)}.to change{User.count}.from(0).to(1)
      end

      it 'cleans up crazy names when trying to create a new user' do
        @auth.stub(:info => double(:name => "this.XKLL 🎂", :nickname => "this.XKLL 🎂"))
        expect{User.find_for_steam_auth(@auth)}.to change{User.count}.from(0).to(1)
      end

    end

    context "existing user" do

      it "returns an existing user if it could find one by uid" do
        create(:user, :uid => '321')
        expect{User.find_for_steam_auth(@auth)}.not_to change{User.count}
      end

      it "updates an existing user with new information" do
        user = create(:user, :name => "Karel", :uid => '321')
        expect{User.find_for_steam_auth(@auth)}.not_to change{User.count}
        user.reload.name.should eql "Kees"
      end

      it "cleans up the nickname when trying to update an existing user" do
        user = create(:user, :name => "Karel", :uid => '321')
        @auth.stub(:uid => '321',
                   :provider => 'steam',
                   :info => double(:name => "this.XKLL 🎂", :nickname => "this.XKLL 🎂")
                  )
        expect{User.find_for_steam_auth(@auth)}.not_to change{User.count}
        user.reload.name.should eql "this.XKLL 🎂"
      end
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
