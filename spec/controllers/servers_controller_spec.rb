require 'spec_helper'

describe ServersController do

  describe "#index" do
    it "should assign the servers variable" do
      first   = create :server, name: "abc"
      third   = create :server, name: "efg"
      second  = create :server, name: "bcd"
      get :index
      assigns(:servers).map(&:name).should eql [first.name, second.name, third.name]
    end
  end

end
