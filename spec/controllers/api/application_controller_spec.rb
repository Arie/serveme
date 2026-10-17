# typed: false
# frozen_string_literal: true

require 'spec_helper'

class TestApiController < Api::ApplicationController
  def index
    render plain: 'ok'
  end
end

describe TestApiController do
  before(:all) do
    Rails.application.routes.draw do
      get '/' => 'test_api#index'
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  it 'responds with 401 if api key invalid' do
    get :index
    response.status.should == 401
  end

  it 'responds with a 200 if the api key is valid' do
    create :user, api_key: 'foobar'
    get :index, params: { api_key: 'foobar' }
    response.status.should == 200
  end

  it 'responds with a 200 if the token is valid' do
    create :user, api_key: 'foobar'
    request.headers.merge!('Authorization' => 'Token token=foobar')
    get :index
    response.status.should == 200
  end

  it 'responds with a 200 if the bearer token is valid' do
    create :user, api_key: 'foobar'
    request.headers.merge!('Authorization' => 'Bearer foobar')
    get :index
    response.status.should == 200
  end

  it 'allows the api user to send a steam uid' do
    api_user = create :user, api_key: 'foobar'
    api_user.groups << Group.admin_group
    steam_user = create :user, uid: '1337'
    get :index, params: { api_key: 'foobar', steam_uid: '1337' }
    controller.current_user.should == steam_user
  end

  it 'lets an admin act as another admin' do
    api_user = create :user, api_key: 'foobar'
    api_user.groups << Group.admin_group
    other_admin = create :user, uid: '1337'
    other_admin.groups << Group.admin_group
    get :index, params: { api_key: 'foobar', steam_uid: '1337' }
    controller.current_user.should == other_admin
  end

  context 'with a trusted api user' do
    let!(:api_user) do
      create(:user, api_key: 'foobar').tap { |u| u.groups << Group.trusted_api_group }
    end

    it 'acts as a regular user' do
      steam_user = create :user, uid: '1337'
      get :index, params: { api_key: 'foobar', steam_uid: '1337' }
      controller.current_user.should == steam_user
    end

    [ :admin_group, :league_admin_group, :config_admin_group, :streamer_group, :trusted_api_group ].each do |group|
      it "can't act as a member of #{group}" do
        privileged = create :user, uid: '1337'
        privileged.groups << Group.public_send(group)
        get :index, params: { api_key: 'foobar', steam_uid: '1337' }
        controller.current_user.should == api_user
      end
    end
  end
end
