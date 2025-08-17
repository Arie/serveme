# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Admin::DonatorsController do
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

    it 'redirects to new when I forgot to enter a donator' do
      post :create, params: { user: { uid: nil } }
      response.should redirect_to(new_admin_donator_path)
      flash[:alert].should == "User not found"
    end

    it 'activates a new donator' do
      non_donator = create :user, uid: 'foobarwidget', name: 'Future', nickname: 'Donator'
      non_donator.groups.should_not include(Group.donator_group)

      post :create, params: { user: { uid: 'foobarwidget' } }

      non_donator.reload.groups.should include(Group.donator_group)
      response.should redirect_to(admin_donator_path(non_donator))
    end

    it 'extends an existing donator' do
      donator = create :user, uid: 'foobar'
      donator.groups << Group.donator_group

      post :create, params: { user: { uid: 'foobar' } }

      response.should redirect_to(edit_admin_donator_path(donator))
    end
  end

  describe '#show' do
    before do
      @user.groups << Group.admin_group
      @product = create :product, price: 10.00
    end

    it 'only shows completed orders in donation history' do
      donator = create :user, nickname: 'Donator'
      donator.groups << Group.donator_group

      complete_order = create :paypal_order, user: donator, product: @product, status: 'Completed'
      pending_order = create :paypal_order, user: donator, product: @product, status: 'Pending'

      get :show, params: { id: donator.id }

      assigns(:orders).should include(complete_order)
      assigns(:orders).should_not include(pending_order)
    end

    it 'includes a link to view user reservations' do
      donator = create :user, nickname: 'Donator'
      donator.groups << Group.donator_group

      get :show, params: { id: donator.id }

      response.body.should include(user_reservations_path(donator))
    end

    it 'shows donator details' do
      @donator = create :user, uid: '12345', nickname: 'Donator'
      @donator.groups << Group.donator_group

      get :show, params: { id: @donator.id }

      response.should render_template(:show)
    end

    it 'calculates statistics correctly' do
      donator = create :user, nickname: 'Donator'
      donator.groups << Group.donator_group
      create :paypal_order, user: donator, product: @product, status: 'Completed'
      create :reservation, user: donator

      get :show, params: { id: donator.id }

      assigns(:lifetime_value).should == 10.00
      assigns(:total_donations).should == 1
      assigns(:total_reservations).should == 1
    end

    it 'includes expired donator periods in history' do
      donator = create :user

      # Ensure donator group exists
      donator_group = Group.donator_group

      # First period - expired
      expired_period = GroupUser.create!(
        user_id: donator.id,
        group_id: donator_group.id,
        expires_at: 1.month.ago,
        created_at: 2.months.ago,
        updated_at: 2.months.ago
      )

      # Verify it was created by accessing it directly without the scope
      GroupUser.where(user_id: donator.id).count.should == 1

      get :show, params: { id: donator.id }

      periods = assigns(:donator_periods)
      periods.should_not be_nil
      periods.count.should == 1
      periods.first.id.should == expired_period.id
    end

    it 'calculates total donator time correctly' do
      donator = create :user

      # Create multiple donator periods
      GroupUser.create!(
        user: donator,
        group: Group.donator_group,
        expires_at: 1.month.from_now,
        created_at: 1.month.ago
      )

      GroupUser.create!(
        user: donator,
        group: Group.donator_group,
        expires_at: 1.year.ago,
        created_at: 2.years.ago
      )

      get :show, params: { id: donator.id }

      assigns(:total_donator_time).should_not be_nil
    end

    it 'formats total donator time with years and months' do
      donator = create :user

      GroupUser.create!(
        user: donator,
        group: Group.donator_group,
        expires_at: 15.months.from_now,
        created_at: Time.current
      )

      get :show, params: { id: donator.id }

      assigns(:total_donator_time).should include('year')
    end
  end

  describe '#lookup_user' do
    before do
      @user.groups << Group.admin_group
    end

    it 'finds user by steam id64' do
      donator = create :user, uid: '76561197961224389'

      get :lookup_user, params: { uid: '76561197961224389' }

      assigns(:donator).should == donator
    end

    it 'finds multiple users by nickname' do
      donator1 = create :user, nickname: 'Arie'
      donator2 = create :user, nickname: 'Arie2'
      donator3 = create :user, nickname: 'Foo'

      get :lookup_user, params: { uid: 'Arie' }

      assigns(:donator).should be_a_new(User)
      flash.now[:notice].should == 'Multiple users found'
    end

    it 'returns empty array for invalid input' do
      get :lookup_user, params: { uid: 'thisuserdoesnotexist' }

      assigns(:donator).should be_a_new(User)
      flash.now[:alert].should == 'User not found'
    end
  end

  describe '#edit' do
    before do
      @user.groups << Group.admin_group
    end

    it 'loads the donator group user' do
      donator = create :user
      donator.groups << Group.donator_group

      get :edit, params: { id: donator.id }

      assigns(:donator).should == donator
    end
  end

  describe '#update' do
    before do
      @user.groups << Group.admin_group
      @donator = create :user
      @donator.groups << Group.donator_group
    end

    it 'updates expiration date' do
      new_date = 1.year.from_now

      # Create an existing GroupUser record
      group_user = @donator.group_users.find_by(group: Group.donator_group)

      patch :update, params: {
        id: @donator.id,
        user: { donator_until: new_date.to_s }
      }

      group_user.reload.expires_at.to_i.should == new_date.to_i
      response.should redirect_to(admin_donators_path)
    end
  end
end
