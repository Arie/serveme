# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe DonatorsController do
  render_views

  before do
    @user = create :user
    sign_in @user
  end

  describe '#leaderboard' do
    context 'when not a donator' do
      it 'redirects to root path' do
        get :leaderboard

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('This feature is only available for donators')
      end
    end

    context 'when user is a donator' do
      before do
        @user.groups << Group.donator_group
      end

      it 'shows the leaderboard page' do
        other_donator = create :user, nickname: 'TopDonator'
        other_donator.groups << Group.donator_group

        # Create orders for leaderboard data
        product = create :product, price: 100
        create :paypal_order, user: other_donator, product: product, status: 'Completed'
        create :paypal_order, user: @user, product: product, status: 'Completed'

        get :leaderboard

        expect(response).to be_successful
        expect(response).to render_template(:leaderboard)
        expect(assigns(:donators)).to include(other_donator, @user)
      end

      it 'calculates lifetime values correctly' do
        product = create :product, price: 50
        create :paypal_order, user: @user, product: product, status: 'Completed'
        create :paypal_order, user: @user, product: product, status: 'Completed'

        get :leaderboard

        expect(assigns(:lifetime_values)[@user.id]).to eq(100)
      end

      it 'excludes non-completed orders from lifetime value' do
        product = create :product, price: 50
        create :paypal_order, user: @user, product: product, status: 'Completed'
        create :paypal_order, user: @user, product: product, status: 'Pending'

        get :leaderboard

        expect(assigns(:lifetime_values)[@user.id]).to eq(50)
      end
    end
  end
end
