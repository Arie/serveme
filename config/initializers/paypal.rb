# typed: strict
# frozen_string_literal: true

if SITE_HOST == 'sea.serveme.tf'
  PayPal::SDK::Core::Config.load('config/paypal.yml', 'sea_production')
else
  PayPal::SDK::Core::Config.load('config/paypal.yml', Rails.env)
end
PayPal::SDK.logger.level = Logger::WARN if Rails.env.test?

PayPal::SDK.configure do |config|
  cert_paths = [
    '/etc/ssl/certs/ca-certificates.crt',  # Debian/Ubuntu/Gentoo
    '/etc/pki/tls/certs/ca-bundle.crt',    # RedHat/CentOS/Fedora
    '/etc/ssl/ca-bundle.pem',              # OpenSUSE
    '/usr/local/etc/openssl/cert.pem',     # macOS via Homebrew
    '/usr/local/share/certs/ca-root-nss.crt', # FreeBSD
  ]

  cert_path = cert_paths.find { |path| File.exist?(path) }

  if cert_path
    config.ssl_options = { ca_file: cert_path }
  else
    Rails.logger.warn "No SSL certificate bundle found. PayPal integration might not work."
  end
end

PayPal::SDK.logger = Rails.logger
