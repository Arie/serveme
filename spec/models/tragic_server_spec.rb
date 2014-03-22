require 'spec_helper'

describe TragicServer do

  describe "#slow_restart" do

    it "tells the web management interface to restart" do
      web_management = double(:web_management)
      subject.stub(:web_management => web_management)

      web_management.should_receive(:restart)

      subject.slow_restart
    end

  end

  describe "#web_management" do

    it "uses the NFO control panel based on hostname" do
      subject.ip = "foobar.tragicservers.com"

      NfoControlPanel.should_receive(:new).with("foobar")

      subject.web_management
    end
  end
end
