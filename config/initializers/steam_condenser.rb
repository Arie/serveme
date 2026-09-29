# typed: strict
# frozen_string_literal: true

steam_api_key = ENV["STEAM_API_KEY"] || Rails.application.credentials.dig(:steam, :api_key)
SteamCondenser::Community::WebApi.api_key = steam_api_key if steam_api_key.present?
