require 'spec_helper'

describe NfoControlPanel do

  subject { NfoControlPanel.new(:ip => "servechi3.tragicservers.com") }

  describe "#restart" do

    it "submits the restart form", :vcr do
      subject.restart
    end

  end
end
