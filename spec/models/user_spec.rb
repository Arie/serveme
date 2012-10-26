require 'spec_helper'

describe User do
  describe '#todays_reservation' do
    it 'returns the users reservation for today' do
      user        = FactoryGirl.create :user
      reservation = FactoryGirl.create :reservation, :user => user
      user.todays_reservation.should == reservation
    end
  end

  describe '#yesterdays_reservation' do
    it 'returns the users reservation for yesterday' do
      user        = FactoryGirl.create :user
      reservation = FactoryGirl.create :reservation, :user => user, :date => Date.yesterday
      user.yesterdays_reservation.should == reservation
    end
  end
end
