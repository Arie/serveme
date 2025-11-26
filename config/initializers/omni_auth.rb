# typed: false
# frozen_string_literal: true

if Rails.env.development?
  OmniAuth.config.request_validation_phase = nil
  OmniAuth.config.silence_get_warning = true
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :steam, Rails.application.credentials.dig(:steam, :api_key)
end

require "openid/fetchers"

# Set CA certificate file path based on OS
if Rails.env.development?
  # macOS with Homebrew
  if File.exist?("/opt/homebrew/etc/ca-certificates/cert.pem")
    OpenID.fetcher.ca_file = "/opt/homebrew/etc/ca-certificates/cert.pem"
  # macOS with MacPorts or other package managers
  elsif File.exist?("/opt/local/etc/openssl/cert.pem")
    OpenID.fetcher.ca_file = "/opt/local/etc/openssl/cert.pem"
  # Linux/Ubuntu
  elsif File.exist?("/etc/ssl/certs/ca-certificates.crt")
    OpenID.fetcher.ca_file = "/etc/ssl/certs/ca-certificates.crt"
  # Fallback to system default
  else
    Rails.logger.warn "No CA certificate file found, Steam authentication may fail"
  end
else
  # Production environments (Linux)
  OpenID.fetcher.ca_file = "/etc/ssl/certs/ca-certificates.crt"
end
