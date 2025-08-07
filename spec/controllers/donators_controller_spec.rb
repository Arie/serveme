# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe DonatorsController do
  render_views

  before do
    @user = create :user
    sign_in @user
  end

  describe '#index' do
    context 'for non-admins' do
      it 'redirect to root for non admins' do
        get :index

        response.should redirect_to(root_path)
      end
    end

    context 'for admins' do
      it 'assigns the donators variable' do
        @user.groups << Group.admin_group

        donator = create :user
        donator.groups << Group.donator_group
        non_donator = create :user

        get :index

        assigns(:donators).should     include(donator)
        assigns(:donators).should_not include(non_donator)
      end
    end
  end

  describe '#create' do
    before do
      @user.groups << Group.admin_group
    end

    it 'renders new again when I forgot to enter a donator' do
      post :create, params: { group_user: { user_id: nil } }
      response.should render_template(:new)
    end

    it 'activates a new donator' do
      non_donator = create :user, uid: 'foobarwidget', name: 'Future', nickname: 'Donator'

      post :create, params: { group_user: { user_id: non_donator.id, expires_at: 3.months.from_now } }

      expect(non_donator.reload).to be_donator
    end

    it 'extends an existing donator' do
      donator = create :user, uid: 'widget', name: 'Existing', nickname: 'Donator'
      donator.groups << Group.donator_group
      gu = GroupUser.last
      gu.expires_at = 10.days.from_now
      gu.save

      post :create, params: { group_user: { user_id: donator.id, expires_at: 20.days.from_now } }

      expect(donator.reload).to be_donator
      expect(gu.reload.expires_at).to be_within(1.minute).of(30.days.from_now)
    end
  end

  describe '#leaderboard' do
    it 'shows a top 25 of donators' do
      @user.groups << Group.donator_group
      user = create :user
      create :paypal_order, user: user, status: 'Completed'

      get :leaderboard
      response.should render_template(:leaderboard)
    end
  end

  describe '#show' do
    before do
      @user.groups << Group.admin_group
      @donator = create :user
      @donator.groups << Group.donator_group
    end

    it 'shows donator details' do
      get :show, params: { id: @donator.id }

      expect(response).to render_template(:show)
      expect(assigns(:user)).to eq(@donator)
      expect(assigns(:lifetime_value)).to eq(0)
    end

    it 'calculates statistics correctly' do
      create :paypal_order, user: @donator, status: 'Completed', product: create(:product, price: 10.0)

      reservation = build :reservation, user: @donator, starts_at: 2.hours.ago, ends_at: 1.hour.ago, duration: 3600
      reservation.save(validate: false)

      get :show, params: { id: @donator.id }

      expect(assigns(:lifetime_value)).to eq(10.0)
      expect(assigns(:total_donations)).to eq(1)
      expect(assigns(:total_reservation_hours)).to eq(1.0)
    end

    it 'includes expired donator periods in history' do
      expired_group_user = GroupUser.create!(
        user: @donator,
        group: Group.donator_group,
        created_at: 6.months.ago,
        expires_at: 3.months.ago
      )

      current_group_user = @donator.group_users.find_by(group: Group.donator_group)
      current_group_user.update!(expires_at: 1.month.from_now)

      get :show, params: { id: @donator.id }

      donator_periods = assigns(:donator_periods)
      expect(donator_periods.count).to eq(2)
      expect(donator_periods).to include(expired_group_user)
      expect(donator_periods).to include(current_group_user)
      expect(donator_periods.first).to eq(current_group_user)
    end

    it 'only shows completed orders in donation history' do
      completed_order = create :paypal_order, user: @donator, status: 'Completed', product: create(:product)
      pending_order = create :paypal_order, user: @donator, status: 'Pending', product: create(:product)
      failed_order = create :paypal_order, user: @donator, status: 'Failed', product: create(:product)

      get :show, params: { id: @donator.id }

      orders = assigns(:orders)
      expect(orders).to include(completed_order)
      expect(orders).not_to include(pending_order)
      expect(orders).not_to include(failed_order)
      expect(orders.count).to eq(1)
    end
  end

  describe '#lookup_user' do
    before do
      @user.groups << Group.admin_group
    end

    it 'finds user by steam id64' do
      target_user = create :user, uid: '76561197960497430'

      post :lookup_user, params: { input: '76561197960497430' }, format: :turbo_stream

      expect(assigns(:user)).to eq(target_user)
      expect(response).to render_template(:lookup_user)
    end

    it 'finds user by nickname' do
      target_user = create :user, nickname: 'TestPlayer'

      post :lookup_user, params: { input: 'TestPl' }, format: :turbo_stream

      expect(assigns(:user)).to eq(target_user)
    end

    it 'returns nil for invalid input' do
      post :lookup_user, params: { input: 'nonexistent' }, format: :turbo_stream

      expect(assigns(:user)).to be_nil
    end
  end

  describe '#edit' do
    before do
      @user.groups << Group.admin_group
      @donator = create :user
      @donator.groups << Group.donator_group
    end

    it 'loads the donator group user' do
      get :edit, params: { id: @donator.id }

      expect(response).to render_template(:edit)
      expect(assigns(:donator).user_id).to eq(@donator.id)
    end
  end

  describe '#update' do
    before do
      @user.groups << Group.admin_group
      @donator = create :user
      @donator.groups << Group.donator_group
      @group_user = GroupUser.last
    end

    it 'updates expiration date' do
      new_date = 60.days.from_now

      patch :update, params: { id: @donator.id, group_user: { expires_at: new_date } }

      expect(@group_user.reload.expires_at).to be_within(1.minute).of(new_date)
      expect(response).to redirect_to(donators_path)
    end
  end
end
