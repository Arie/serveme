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

end
