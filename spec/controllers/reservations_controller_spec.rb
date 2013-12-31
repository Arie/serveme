require 'spec_helper'

describe ReservationsController do

  before do
    @user         = create :user
    sign_in @user
  end

  describe '#show' do

    it "redirects to new_reservation_path when it cant find the reservation" do
      get :show, :id => 'foo'
      response.should redirect_to(new_reservation_path)
    end

  end

  describe "#update" do

    it "redirects to root_path when it tries to update a reservation that is over" do
      reservation = create :reservation, :user => @user
      reservation.update_attribute(:ends_at, 1.hour.ago)

      put :update, :id => reservation.id
      response.should redirect_to(root_path)
    end

  end

end
