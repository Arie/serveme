require 'spec_helper'

describe User do
  describe '#todays_reservation' do
    it 'returns the users reservation for today' do
      user        = create :user
      reservation = create :reservation, :user => user
      user.todays_reservation.should == reservation
    end
  end

  describe '#yesterdays_reservation' do
    it 'returns the users reservation for yesterday' do
      user        = create :user
      reservation = create :reservation, :user => user, :date => Date.yesterday
      user.yesterdays_reservation.should == reservation
    end
  end

  describe "#reservation" do

    context "just aftermidnight" do

      it "returns yesterdays reservation" do
        subject.stub(:just_after_midnight? => true)
        subject.should_receive(:yesterdays_reservation)
        subject.reservation
      end

    end

    context "not just after midnight" do

      it "returns todays reservation" do
        subject.stub(:just_after_midnight? => false)
        subject.should_receive(:todays_reservation)
        subject.reservation
      end

    end

  end

  describe "#steam_profile_url" do

    it "creates a steam profile url based on the uid" do
      subject.stub(:uid => '123')
      subject.steam_profile_url.should eql "http://steamcommunity.com/profiles/123"
    end

  end
end
