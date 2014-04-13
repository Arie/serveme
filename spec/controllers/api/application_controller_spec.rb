require 'spec_helper'

class TestApiController < Api::ApplicationController

  def index
    render :text => "ok"
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
    get :index, api_key: 'foobar'
    response.status.should == 200
  end

end

