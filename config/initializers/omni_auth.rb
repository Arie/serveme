Rails.application.config.middleware.use OmniAuth::Builder do
  provider :steam, STEAM_WEB_API_KEY
end

require "openid/fetchers"
OpenID.fetcher.ca_file = "/etc/ssl/certs/ca-certificates.crt"
