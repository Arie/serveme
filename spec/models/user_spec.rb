require 'spec_helper'

describe User do

  describe "#steam_profile_url" do

    it "creates a steam profile url based on the uid" do
      subject.stub(:uid => '123')
      subject.steam_profile_url.should eql "http://steamcommunity.com/profiles/123"
    end

  end

end
