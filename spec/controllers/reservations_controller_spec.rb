require 'spec_helper'

describe ReservationsController do

  before do
    @user         = create :user
    sign_in @user
  end

  describe '#show' do

    it "redirect to root_path when it cant find the reservation" do
      get :show, :id => 'foo'
      response.should redirect_to(new_reservation_path)
    end
  end

end
