# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Api::SdrController do
  render_views

  before do
    @user = create :user
    controller.stub(api_user: @user)
    @server = create :server, ip: '176.9.138.143', port: '27015',
                              last_sdr_ip: '169.254.1.2', last_sdr_port: '12345'
  end

  describe '#show' do
    it 'resolves a connect string to SDR details' do
      get :show, params: { ip_port: 'connect 176.9.138.143:27015; password "foo"' }, format: :json

      expect(response).to have_http_status(:ok)
      json = {
        ip_port: 'connect 176.9.138.143:27015; password "foo"',
        sdr_ip: '169.254.1.2',
        sdr_port: '12345',
        connect_string: 'connect 169.254.1.2:12345; password "foo"'
      }
      expect(response.body).to match_json_expression(json)
    end

    it 'resolves a bare ip:port to the SDR ip:port' do
      get :show, params: { ip_port: '176.9.138.143:27015' }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to match_json_expression(
        { sdr_ip: '169.254.1.2', sdr_port: '12345', connect_string: '169.254.1.2:12345' }.ignore_extra_keys!
      )
    end

    it 'returns 404 when the server can not be resolved to SDR details' do
      get :show, params: { ip_port: '1.1.1.1:27015' }, format: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 401 when no valid api user is present' do
      controller.stub(api_user: nil)

      get :show, params: { ip_port: '176.9.138.143:27015' }, format: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
