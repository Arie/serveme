require 'spec_helper'

describe Api::ServersController do

  render_views

  before do
    @user = create :user
    @server = create :server, name: "The Server"
    controller.stub(:current_user => @user)
  end

  describe "#index" do
    it 'renders a json with the servers info' do
      get :index, format: :json
      json = {
        servers: [
          { name: "The Server" }.ignore_extra_keys!
        ]
      }
      expect(response.body).to match_json_expression(json)
    end
  end
end
