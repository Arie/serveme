require 'spec_helper'

describe Api::UsersController do

  render_views

  before do
    @user = create :user, :uid => "the-uid", :nickname => "the-nickname", :name => "the-name"
    controller.stub(:current_user => @user)
  end

  describe "#show" do

    it "renders a json describing the user" do
      get :show, :id => @user.uid, :format => :json

      json = {
        user: {
          id: Integer,
          uid: "the-uid",
          nickname: "the-nickname",
          name: "the-name",
          donator: false,
          donator_until: nil,
          reservations_made: Integer,
          total_reservation_seconds: Integer,
        }
      }
      expect(response.body).to match_json_expression(json)
    end

  end

end

