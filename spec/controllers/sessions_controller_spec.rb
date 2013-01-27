require 'spec_helper'

describe SessionsController do

  before { @request.env["devise.mapping"] = Devise.mappings[:user] }

  describe '#steam' do
    it "auths a user with omniauth" do
      user = create(:user, :uid => '12345', :provider => 'steam')
      OmniAuth.config.add_mock(:steam, {:uid => '12345'})
      request.env["omniauth.auth"] = OmniAuth.config.mock_auth[:steam]
      User.should_receive(:find_for_steam_auth).with(OmniAuth.config.mock_auth[:steam]).and_return(user)
      get :steam
    end
  end

  describe "#passthru" do

    it "renders a 404" do
      post :passthru
      response.status.should eql(404)
    end

  end
end
