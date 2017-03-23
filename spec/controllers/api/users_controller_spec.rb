require 'spec_helper'

describe Api::UsersController do

  render_views

  before do
    @user = create :user, :uid => 12345, :nickname => "the-nickname", :name => "the-name"
    controller.stub(:current_user => @user)
  end

  describe "#show" do

    it "renders a json describing the user" do
      get :show, params: { id: @user.uid, format: :json }

      json = {
        user: {
          id: Integer,
          uid: "12345",
          nickname: "the-nickname",
          name: "the-name",
          donator: false,
          donator_until: nil,
          reservations_made: Integer,
          total_reservation_seconds: Integer,
        }
      }
      expect(response.status).to eql 200
      expect(response.body).to match_json_expression(json)
    end

  end

end

