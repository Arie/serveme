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
        product = create :product, price: 100, days: 30
        create :paypal_order, user: other_donator, product: product, status: 'Completed'
        create :paypal_order, user: @user, product: product, status: 'Completed'

        get :leaderboard

        expect(response).to be_successful
        expect(response).to render_template(:leaderboard)
        # Check that donators is an array of [user, days] pairs
        donator_users = assigns(:donators).map(&:first)
        expect(donator_users).to include(other_donator, @user)
      end

      it 'calculates lifetime values correctly' do
        product = create :product, price: 50, days: 30
        create :paypal_order, user: @user, product: product, status: 'Completed'
        create :paypal_order, user: @user, product: product, status: 'Completed'

        get :leaderboard

        expect(assigns(:lifetime_values)[@user.id]).to eq(100)
      end

      it 'excludes non-completed orders from lifetime value' do
        product = create :product, price: 50, days: 30
        create :paypal_order, user: @user, product: product, status: 'Completed'
        create :paypal_order, user: @user, product: product, status: 'Pending'

        get :leaderboard

        expect(assigns(:lifetime_values)[@user.id]).to eq(50)
      end

      it 'correctly calculates lifetime values for multiple donators with different products' do
        donator1 = create :user, nickname: 'Donator1'
        donator2 = create :user, nickname: 'Donator2'
        donator1.groups << Group.donator_group
        donator2.groups << Group.donator_group

        product_small = create :product, price: 10, days: 7
        product_medium = create :product, price: 25, days: 30
        product_large = create :product, price: 100, days: 365

        create :paypal_order, user: donator1, product: product_small, status: 'Completed'
        create :paypal_order, user: donator1, product: product_medium, status: 'Completed'
        create :paypal_order, user: donator1, product: product_large, status: 'Completed'

        create :paypal_order, user: donator2, product: product_medium, status: 'Completed'
        create :paypal_order, user: donator2, product: product_medium, status: 'Completed'

        create :paypal_order, user: @user, product: product_large, status: 'Completed'

        create :paypal_order, user: donator1, product: product_large, status: 'Pending'
        create :paypal_order, user: donator2, product: product_large, status: 'Failed'

        get :leaderboard

        lifetime_values = assigns(:lifetime_values)
        expect(lifetime_values[donator1.id]).to eq(135)
        expect(lifetime_values[donator2.id]).to eq(50)
        expect(lifetime_values[@user.id]).to eq(100)

        donation_counts = assigns(:donation_counts)
        expect(donation_counts[donator1.id]).to eq(3)
        expect(donation_counts[donator2.id]).to eq(2)
        expect(donation_counts[@user.id]).to eq(1)
      end

      it 'ranks donators by total days purchased' do
        donator1 = create :user, nickname: 'Donator1'
        donator2 = create :user, nickname: 'Donator2'
        donator1.groups << Group.donator_group
        donator2.groups << Group.donator_group

        product_year = create :product, price: 100, days: 365
        product_month = create :product, price: 10, days: 35
        create :paypal_order, user: donator1, product: product_year, status: 'Completed'
        create :paypal_order, user: donator1, product: product_month, status: 'Completed'

        product_lifetime = create :product, price: 200, days: 500
        create :paypal_order, user: donator2, product: product_lifetime, status: 'Completed'

        product_small = create :product, price: 5, days: 30
        create :paypal_order, user: @user, product: product_small, status: 'Completed'

        get :leaderboard

        donators = assigns(:donators)
        expect(donators[0][0]).to eq(donator2)
        expect(donators[0][1]).to eq(1460)
        expect(donators[1][0]).to eq(donator1)
        expect(donators[1][1]).to eq(400)
        expect(donators[2][0]).to eq(@user)
        expect(donators[2][1]).to eq(30)
      end
    end
  end
end
