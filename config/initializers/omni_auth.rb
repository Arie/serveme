# typed: false
# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :steam, Rails.application.credentials.dig(:steam, :api_key)
end

require "openid/fetchers"
OpenID.fetcher.ca_file = "/etc/ssl/certs/ca-certificates.crt"
