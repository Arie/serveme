# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ApplicationController do
  controller(PagesController) do
    skip_before_action :authenticate_user!
    define_method(:index) do ||
      render plain: 'foo'
    end
  end

  context 'with an invalid time zone cookie' do
    it 'falls back to the default time zone' do
      cookies[:time_zone] = 'Etc/GMT 2'
      Time.should_receive(:zone=).with('Etc/GMT 2').and_call_original
      Time.should_receive(:zone=).with(Rails.configuration.time_zone).and_call_original
      get :index
    end
  end

  context 'with a valid time zone cookie' do
    it 'changes the time zone' do
      time_zone_before_request = Time.zone

      new_time_zone =
        if time_zone_before_request == 'Europe/Amsterdam'
          'Europe/London'
        else
          'Europe/Amsterdam'
        end

      cookies[:time_zone] = new_time_zone
      Time.should_receive(:zone=).with(new_time_zone).once
      get :index

      Time.zone.to_s.should_not eql(time_zone_before_request)
    end
  end

  context 'with a logged-in user with a saved timezone' do
    controller(PagesController) do
      skip_before_action :authenticate_user!
      define_method(:index) do ||
        render plain: 'foo'
      end
    end

    let(:user) { create(:user, time_zone: 'America/New_York') }

    before do
      sign_in user
    end

    it 'users timezone from cookie if none set on the user' do
      user.update_attribute(:time_zone, nil)
      cookies[:time_zone] = 'Europe/London'

      Time.should_receive(:zone=).with('Europe/London').once.and_call_original

      get :index

      expect(Time.zone.tzinfo.identifier).to eq('Europe/London')
    end

    it 'uses the saved timezone and does not overwrite with cookie' do
      cookies[:time_zone] = 'Europe/London'

      Time.should_receive(:zone=).with('America/New_York').once.and_call_original
      Time.should_not_receive(:zone=).with('Europe/London')

      get :index
    end
  end

  context 'when user is on a VPN' do
    controller(PagesController) do
      skip_before_action :redirect_if_country_banned
      define_method(:index) do ||
        render plain: 'foo'
      end
    end

    let(:user) { create(:user) }
    let(:vpn_ip) { '1.1.1.1' }

    before do
      sign_in user
      user.update(current_sign_in_ip: vpn_ip)
      allow(ReservationPlayer).to receive(:banned_asn_ip?).with(vpn_ip).and_return(true)
    end

    it 'signs out the user and shows flash message' do
      get :index

      expect(response).to redirect_to('/')
      expect(flash[:alert]).to eq('You appear to be on a VPN, please log in without it')
      expect(controller.current_user).to be_nil
    end

    it 'logs the sign out' do
      expect(Rails.logger).to receive(:info).with(/Logging out player on VPN/).once.and_call_original
      allow(Rails.logger).to receive(:info).and_call_original
      get :index
    end
  end

  context 'when admin user is on a VPN' do
    controller(PagesController) do
      skip_before_action :redirect_if_country_banned
      define_method(:index) do ||
        render plain: 'foo'
      end
    end

    let(:admin_user) { create(:user, :admin) }
    let(:vpn_ip) { '1.1.1.1' }

    before do
      sign_in admin_user
      admin_user.update(current_sign_in_ip: vpn_ip)
      allow(ReservationPlayer).to receive(:banned_asn_ip?).with(vpn_ip).and_return(true)
    end

    it 'allows admin to stay signed in' do
      get :index

      expect(response).to have_http_status(:success)
      expect(controller.current_user).to eq(admin_user)
    end
  end
end
