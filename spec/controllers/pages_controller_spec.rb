require 'spec_helper'

describe PagesController do

  describe "#recent_reservations" do
    it "should assign the recent reservations variable" do
      reservation = create :reservation
      get :recent_reservations
      assigns(:recent_reservations).should include(reservation)
    end
  end

  describe '#top_10' do
    it "should assign the top 10 hash" do
      Statistic.should_receive(:top_10).and_return(:foo)
      get :top_10
      assigns(:top_10_hash).should eql(:foo)
    end
  end

  describe "#servers" do
    it "should assign the servers variable" do
      @user = create :user
      sign_in @user

      servers = ['foo']
      Server.should_receive(:reservable_by_user).with(@user).and_return(servers)
      get :servers
      assigns(:servers).should eql servers
    end
  end

end
