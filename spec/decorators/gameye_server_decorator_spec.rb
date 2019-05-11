require 'spec_helper'

describe GameyeServerDecorator do

  let(:reservation) { double(:reservation) }
  let(:server) { build(:server, :name => "Name") }
  subject { GameyeServerDecorator.new(server) }

  before do
    server.stub(:reservation => reservation)
  end

  describe "locations" do
    it "knows the location names and flags" do
      reservation.stub(gameye_location: "amsterdam")
      expect(subject.location_name).to eql "Amsterdam"
      expect(subject.location_flag).to eql "nl"

      reservation.stub(gameye_location: "chicago")
      expect(subject.location_name).to eql "Chicago"
      expect(subject.location_flag).to eql "us"

      reservation.stub(gameye_location: "moscow")
      expect(subject.location_name).to eql "Moscow"
      expect(subject.location_flag).to eql "ru"

      reservation.stub(gameye_location: "warsaw")
      expect(subject.location_name).to eql "Warsaw"
      expect(subject.location_flag).to eql "pl"
    end
  end

  describe "#flag" do
    it "returns an empty string if it's unknown" do
      subject.stub(:location_flag => nil)
      expect(subject.flag).to eql ""
    end

    it "returns a formatted span with name and flag if it is known" do
      subject.stub(:location_flag => "nl", :location_name => "Rotterdam")
      expect(subject.flag).to eql '<span class="flags flags-nl" title="Rotterdam"></span>'
    end
  end
end
