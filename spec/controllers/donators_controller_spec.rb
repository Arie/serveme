require 'spec_helper'

describe DonatorsController do

  render_views

  before do
    @user         = create :user
    sign_in @user
  end

  describe "#index" do

    context "for non-admins" do

      it "redirect to root for non admins" do

        get :index

        response.should redirect_to(root_path)
      end

    end

    context "for admins"

      it "assigns the donators variable" do
        @user.groups << Group.admin_group

        donator     = create :user
        donator.groups << Group.donator_group
        non_donator = create :user

        get :index

        assigns(:donators).should     include(donator)
        assigns(:donators).should_not include(non_donator)
      end

  end

  describe "#create" do

    it "renders new again when I forgot to enter a donator" do
      @user.groups << Group.admin_group

      post :create, params: { group_user: { user_id:  nil} }
      response.should render_template(:new)
    end

  end

  describe "#leaderboard" do

    it "shows a top 25 of donators" do
      @user.groups << Group.donator_group
      user = create :user
      create :paypal_order, :user => user, :status => "Completed"

      get :leaderboard
      response.should render_template(:leaderboard)
    end

  end
end
