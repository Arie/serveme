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
    it 'allows the user to update the logs.tf api key' do
      post :update, :user => { :logs_tf_api_key => 'abc' }
      @user.reload.logs_tf_api_key.should eql 'abc'
    end

    it "ignores other parameters" do
      post :update, :user => { :nickname => 'foobar' }
      @user.reload.nickname.should_not eql 'abc'
    end
  end
end
