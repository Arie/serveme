require 'spec_helper'

class TestApiController < Api::ApplicationController

  def index
    render :plain => "ok"
  end

end

describe TestApiController do

  before do
    Rails.application.routes.draw do
      get '/' => "test_api#index"
    end
  end

  after do
    Rails.application.reload_routes!
  end

  it "responds with 401 if api key invalid" do
    get :index
    response.status.should == 401
  end

  it 'responds with a 200 if the api key is valid' do
    create :user, :api_key => "foobar"
    get :index, params: { api_key: 'foobar' }
    response.status.should == 200
  end

  it 'allows the api user to send a steam uid' do
    api_user    = create :user, :api_key => "foobar"
    api_user.groups << Group.admin_group
    steam_user  = create :user, :uid => "1337"
    get :index, params: { api_key: 'foobar', steam_uid: "1337" }
    controller.current_user.should == steam_user
  end

end

