require 'spec_helper'

describe UsersController do

  before do
    @user = create :user
    sign_in @user
  end

  describe "#edit" do
    it "should assign the user variable" do
      get :edit
      assigns(:user).should eql @user
    end
  end

  describe '#update' do
    it 'allows the user to update the time zone key' do
      post :update, :user => { :time_zone => 'Europe/Amsterdam' }
      @user.reload.time_zone.should eql 'Europe/Amsterdam'
      get :edit
      Time.zone.to_s.should include(@user.time_zone)
    end

    it "ignores other parameters" do
      post :update, :user => { :nickname => 'foobar' }
      @user.reload.nickname.should_not eql 'abc'
    end
  end
end
