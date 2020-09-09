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

      post :create, params: { group_user: { user_id: non_donator.uid, expires_at: 3.months.from_now } }

      expect(non_donator.reload).to be_donator
    end

    it 'extends an existing donator' do
      donator = create :user, uid: 'widget', name: 'Existing', nickname: 'Donator'
      donator.groups << Group.donator_group
      gu = GroupUser.last
      gu.expires_at = 10.days.from_now
      gu.save

      post :create, params: { group_user: { user_id: donator.uid, expires_at: 20.days.from_now } }

      expect(donator.reload).to be_donator
      expect(gu.reload.expires_at).to be > 29.days.from_now
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
end
