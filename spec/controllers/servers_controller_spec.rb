require 'spec_helper'

describe ServersController do

  describe "#index" do
    it "should assign the servers variable" do
      servers = ['foo']
      Server.should_receive(:ordered).and_return(servers)
      get :index
      assigns(:servers).should eql servers
    end
  end

end
