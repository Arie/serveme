require 'spec_helper'

describe ReservationsController do

  before do
    @user = FactoryGirl.create :user
    sign_in @user
    request.env['warden'].stub :authenticate! => @user
    controller.stub :current_user => @user
  end

  it "should not allow reservations during the lockout" do
    subject.stub(:just_after_midnight?).and_return { true }
    get :new
    response.should redirect_to '/'
  end

  context "show" do

    it "shows todays reservation during normal hours" do
      @user.stub(:just_after_midnight?).and_return { false }
      yesterdays_reservation  = FactoryGirl.create :reservation, :date => Date.yesterday, :user => @user
      todays_reservation      = FactoryGirl.create :reservation, :date => Date.today,     :user => @user
      get :show, :id => 1337
      controller.reservation.should == todays_reservation
    end

    it "shows yesterdays reservation during lockout" do
      @user.stub(:just_after_midnight?).and_return { true }
      yesterdays_reservation  = FactoryGirl.create :reservation, :date => Date.yesterday, :user => @user
      todays_reservation      = FactoryGirl.create :reservation, :date => Date.today,     :user => @user
      get :show, :id => 1337
      controller.reservation.should == yesterdays_reservation
    end

  end
end
