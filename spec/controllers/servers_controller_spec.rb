require 'spec_helper'

describe ServersController do

  before do
    Server.delete_all
    @user         = create :user
    @user.groups << Group.donator_group
    sign_in @user
  end

  describe "#index" do
    render_views
    it "should assign the servers variable" do
      first   = create :server, name: "abc"
      third   = create :server, name: "efg"
      second  = create :server, name: "bcd"
      _stat   = create :server_statistic, server: first, reservation_id: 1, created_at: 1.minute.ago
      get :index
      assigns(:servers).map(&:name).should eql [first.name, second.name, third.name]
    end
  end

end
