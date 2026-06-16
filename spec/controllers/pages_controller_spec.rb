# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe PagesController do
  before do
    @user = create :user
    @user.groups << Group.donator_group
    @user.groups << Group.admin_group
    sign_in @user
  end

  describe '#recent_reservations' do
    it 'should assign the recent reservations variable' do
      reservation = create :reservation
      get :recent_reservations
      assigns(:recent_reservations).should include(reservation)
    end
  end

  describe '#statistics' do
    it 'should assign the top 10 hash' do
      Statistic.should_receive(:top_10_users).and_return(:foo)
      Statistic.should_receive(:top_10_servers).and_return(:bar)
      get :statistics
      assigns(:top_10_users_hash).should eql(:foo)
      assigns(:top_10_servers_hash).should eql(:bar)
    end
  end

  describe '#faq' do
    it 'renders' do
      get :faq

      response.should be_successful
    end
  end

  describe '#not_found' do
    it 'should show the not found page' do
      get :not_found
      response.should render_template('pages/not_found')
      response.status.should == 404
    end
  end

  describe '#error' do
    it 'should show the error page' do
      get :error
      response.should render_template('pages/error')
      response.status.should == 500
    end
  end

  describe "#welcome redesign gating" do
    it "renders the v2 layout + template when opted in" do
      request.cookies["ui_v2"] = "true"
      get :welcome
      expect(response).to render_template("layouts/application_v2")
      expect(response).to render_template("pages/welcome")
    end

    it "renders the default layout when not opted in" do
      cookies.delete(:ui_v2) if respond_to?(:cookies)
      get :welcome
      expect(response).not_to render_template("layouts/application_v2")
    end
  end

  describe "#welcome cache key" do
    it "varies the action-cache key by the ui_v2 cookie" do
      sign_out @user
      get :welcome
      without_cookie = controller.send(:welcome_cache_path)
      request.cookies["ui_v2"] = "true"
      get :welcome
      with_cookie = controller.send(:welcome_cache_path)
      expect(with_cookie).not_to eq(without_cookie)
      expect(with_cookie).to include("true")
    end
  end
end
