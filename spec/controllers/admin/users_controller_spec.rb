# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Admin::UsersController do
  render_views

  before do
    @admin = create :user
    @admin.groups << Group.admin_group
    sign_in @admin
  end

  describe '#index' do
    context 'for non-admins' do
      it 'redirects to root for non admins' do
        regular_user = create :user
        sign_in regular_user

        get :index

        response.should redirect_to(root_path)
      end
    end

    context 'for admins' do
      it 'filters users by search term' do
        user1 = create :user, nickname: "TestPlayer"
        user2 = create :user, nickname: "OtherPlayer"

        get :index, params: { search: "Test" }

        assigns(:users).should include(user1)
        assigns(:users).should_not include(user2)
      end

      it 'filters users by group' do
        donator = create :user
        donator.groups << Group.donator_group
        regular_user = create :user

        get :index, params: { group_id: Group.donator_group.id }

        assigns(:users).should include(donator)
        assigns(:users).should_not include(regular_user)
      end

      it 'calculates lifetime values for displayed users' do
        user = create :user
        product = create :product, price: 10.0
        create :paypal_order, user: user, product: product, status: "Completed"

        get :index

        assigns(:lifetime_values)[user.id].should == 10.0
      end
    end
  end

  describe '#show' do
    before do
      @user = create :user
    end

    it 'loads user' do
      product = create :product, price: 25.0
      order = create :paypal_order, user: @user, product: product, status: "Completed"
      voucher = create :voucher, product: product, claimed_by: @user, claimed_at: Time.current
      reservation = create :reservation, user: @user, duration: 3600

      get :show, params: { id: @user.id }

      assigns(:user).should eql @user
      assigns(:orders).should include(order)
      assigns(:vouchers).should include(voucher)
      assigns(:reservations).should include(reservation)

      assigns(:lifetime_value).should eql 25.0
      assigns(:total_donations).should eql 1
      assigns(:total_reservations).should eql 1
      assigns(:total_reservation_hours).should eql 1.0
    end
  end

  describe '#new' do
    it 'renders the new user form' do
      get :new

      response.should be_successful
      assigns(:user).should be_a(User)
    end

    it 'performs lookup if uid is provided' do
      existing_user = create :user, uid: "76561197960497430"

      get :new, params: { uid: "76561197960497430" }

      assigns(:users).should == [ existing_user ]
    end
  end

  describe '#create' do
    context 'with new Steam ID64' do
      it 'creates a new user' do
        expect {
          post :create, params: { user: { uid: "76561197960497431" } }
        }.to change(User, :count).by(1)

        new_user = User.find_by(uid: "76561197960497431")
        response.should redirect_to(admin_user_path(new_user))
      end
    end
  end

  describe '#edit' do
    before do
      @user = create :user
    end

    it 'renders the edit form' do
      get :edit, params: { id: @user.id }

      response.should be_successful
      assigns(:user).should eql @user
      assigns(:groups).should_not be_empty
    end
  end

  describe '#update' do
    before do
      @user = create :user
    end

    context 'updating user attributes' do
      it 'updates user nickname' do
        patch :update, params: { id: @user.id, user: { nickname: "NewNickname" } }

        @user.reload.nickname.should eql "NewNickname"
        response.should redirect_to(admin_user_path(@user))
        flash[:notice].should == "User updated successfully"
      end
    end

    context 'group management' do
      describe 'adding user to group' do
        it 'adds user to a group' do
          patch :update, params: {
            id: @user.id,
            group_action: "add",
            group_id: Group.donator_group.id,
            expires_at: 1.month.from_now.to_s
          }

          @user.reload.groups.should include(Group.donator_group)
          response.should redirect_to(edit_admin_user_path(@user))
          flash[:notice].should == "User added to Donators"
        end

        it 'prevents duplicate group membership' do
          @user.groups << Group.donator_group

          patch :update, params: {
            id: @user.id,
            group_action: "add",
            group_id: Group.donator_group.id
          }

          response.should redirect_to(edit_admin_user_path(@user))
          flash[:alert].should == "User is already in Donators"
        end

        it 'updates donator_until when adding to donator group' do
          expires_at = 1.month.from_now

          patch :update, params: {
            id: @user.id,
            group_action: "add",
            group_id: Group.donator_group.id,
            expires_at: expires_at.to_s
          }

          @user.reload.donator_until.should be_within(1.second).of(expires_at)
        end
      end

      describe 'removing user from group' do
        before do
          @user.groups << Group.donator_group
        end

        it 'removes user from a group' do
          patch :update, params: {
            id: @user.id,
            group_action: "remove",
            group_id: Group.donator_group.id
          }

          @user.reload.groups.should_not include(Group.donator_group)
          response.should redirect_to(edit_admin_user_path(@user))
          flash[:notice].should == "User removed from Donators"
        end
      end

      describe 'updating group expiry' do
        before do
          @user.groups << Group.donator_group
          @group_user = @user.group_users.find_by(group: Group.donator_group)
        end

        it 'updates group membership expiry' do
          new_expiry = 2.months.from_now

          patch :update, params: {
            id: @user.id,
            group_action: "update_expiry",
            group_user_id: @group_user.id,
            expires_at: new_expiry.to_s
          }

          @group_user.reload.expires_at.should be_within(1.second).of(new_expiry)
          response.should redirect_to(edit_admin_user_path(@user))
          flash[:notice].should == "Group membership updated"
        end

        it 'updates donator_until for donator group' do
          new_expiry = 2.months.from_now

          patch :update, params: {
            id: @user.id,
            group_action: "update_expiry",
            group_user_id: @group_user.id,
            expires_at: new_expiry.to_s
          }

          @user.reload.donator_until.should be_within(1.second).of(new_expiry)
        end
      end
    end
  end

  describe '#lookup_user' do
    context 'with Steam ID64' do
      it 'creates user if not found' do
        expect {
          post :lookup_user, params: { input: "76561197960497432" }, format: :turbo_stream
        }.to change(User, :count).by(1)

        assigns(:users).count.should eql 1
        assigns(:user).uid.should eql "76561197960497432"
      end

      it 'finds existing user' do
        user = create :user, uid: "76561197960497433"

        post :lookup_user, params: { input: "76561197960497433" }, format: :turbo_stream

        assigns(:users).should eql [ user ]
        assigns(:user).should eql user
      end
    end

    context 'with nickname search' do
      it 'finds users by partial nickname match' do
        user1 = create :user, nickname: "TestPlayer123"
        user2 = create :user, nickname: "TestPlayer456"
        user3 = create :user, nickname: "OtherPlayer"

        post :lookup_user, params: { input: "TestPlayer" }, format: :turbo_stream

        assigns(:users).should include(user1, user2)
        assigns(:users).should_not include(user3)
      end
    end
  end
end
