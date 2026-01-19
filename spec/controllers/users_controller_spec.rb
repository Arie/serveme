# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe UsersController do
  before do
    @user = create :user
    sign_in @user
  end

  describe '#edit' do
    it 'should assign the user variable' do
      get :edit
      assigns(:user).should eql @user
    end
  end

  describe '#update' do
    it 'allows the user to update the logs.tf api key' do
      post :update, params: { user: { logs_tf_api_key: 'abc' } }
      @user.reload.logs_tf_api_key.should eql 'abc'
    end

    it 'allows the user to update the time zone key' do
      post :update, params: { user: { time_zone: 'Europe/Amsterdam' } }
      @user.reload.time_zone.should eql 'Europe/Amsterdam'
      get :edit
      Time.zone.to_s.should include(@user.time_zone)
    end

    it 'ignores other parameters' do
      post :update, params: { user: { nickname: 'foobar' } }
      @user.reload.nickname.should_not eql 'abc'
    end
  end

  describe '#unlink_discord' do
    it 'unlinks a linked discord account' do
      @user.update!(discord_uid: '123456789')
      delete :unlink_discord
      @user.reload.discord_uid.should be_nil
      flash[:notice].should eq 'Discord account unlinked'
    end

    it 'shows alert when no discord account is linked' do
      @user.update!(discord_uid: nil)
      delete :unlink_discord
      flash[:alert].should eq 'No Discord account linked'
    end

    it 'redirects to settings page' do
      delete :unlink_discord
      response.should redirect_to(settings_path)
    end
  end
end
