# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe 'API Authentication Methods', type: :request do
  let(:user) { create(:user).tap { |u| u.generate_api_key! } }
  let(:api_key) { user.api_key }

  describe 'Query Parameter Authentication' do
    it 'authenticates with api_key query parameter' do
      get "/api/users/#{user.uid}", params: { api_key: api_key }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['user']['uid']).to eq(user.uid)
    end

    it 'returns 401 with invalid api_key query parameter' do
      get "/api/users/#{user.uid}", params: { api_key: 'invalid' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Token Header Authentication (Legacy Format)' do
    it 'authenticates with Authorization: Token token=api_key header' do
      get "/api/users/#{user.uid}", headers: { 'Authorization' => "Token token=#{api_key}" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['user']['uid']).to eq(user.uid)
    end

    it 'returns 401 with invalid Token header' do
      get "/api/users/#{user.uid}", headers: { 'Authorization' => 'Token token=invalid' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Bearer Token Authentication (Modern Format)' do
    it 'authenticates with Authorization: Bearer api_key header' do
      get "/api/users/#{user.uid}", headers: { 'Authorization' => "Bearer #{api_key}" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['user']['uid']).to eq(user.uid)
    end

    it 'returns 401 with invalid Bearer token' do
      get "/api/users/#{user.uid}", headers: { 'Authorization' => 'Bearer invalid' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Authentication Method Compatibility' do
    it 'supports all three authentication methods for the same endpoint' do
      get "/api/users/#{user.uid}", params: { api_key: api_key }
      expect(response).to have_http_status(:ok)

      get "/api/users/#{user.uid}", headers: { 'Authorization' => "Token token=#{api_key}" }
      expect(response).to have_http_status(:ok)

      get "/api/users/#{user.uid}", headers: { 'Authorization' => "Bearer #{api_key}" }
      expect(response).to have_http_status(:ok)
    end

    it 'query parameter takes precedence over header when both are provided' do
      valid_api_key = api_key
      invalid_api_key = 'invalid'

      get "/api/users/#{user.uid}",
          params: { api_key: valid_api_key },
          headers: { 'Authorization' => "Bearer #{invalid_api_key}" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'No Authentication' do
    it 'returns 401 when no authentication is provided' do
      get "/api/users/#{user.uid}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
