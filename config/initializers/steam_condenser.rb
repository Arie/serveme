# typed: false
# frozen_string_literal: true

if Rails.application.credentials.dig(:steam, :api_key).present?
  SteamCondenser::Community::WebApi.api_key = Rails.application.credentials.dig(:steam, :api_key)
end
