# typed: strict
# frozen_string_literal: true

if SITE_HOST == "sea.serveme.tf"
  PayPal::SDK::Core::Config.load("config/paypal.yml", "sea_production")
else
  PayPal::SDK::Core::Config.load("config/paypal.yml", Rails.env)
end
PayPal::SDK.logger.level = Logger::WARN if Rails.env.test?

PayPal::SDK.configure do |config|
  cert_paths = [
    "/etc/ssl/certs/ca-certificates.crt",  # Debian/Ubuntu/Gentoo
    "/etc/pki/tls/certs/ca-bundle.crt",    # RedHat/CentOS/Fedora
    "/etc/ssl/ca-bundle.pem",              # OpenSUSE
    "/usr/local/etc/openssl/cert.pem",     # macOS via Homebrew
    "/usr/local/share/certs/ca-root-nss.crt" # FreeBSD
  ]

  cert_path = cert_paths.find { |path| File.exist?(path) }

  if cert_path
    config.ssl_options = { ca_file: cert_path }
  else
    Rails.logger.warn "No SSL certificate bundle found. PayPal integration might not work."
  end
end

PayPal::SDK.logger = Rails.logger

# Fix encoding issue: PayPal API responses come back as ASCII-8BIT,
# but MultiJson's json_gem adapter uses String#encode which tries to
# transcode rather than re-tag. This fails on valid UTF-8 multi-byte
# characters (e.g. accented names). Force-encoding to UTF-8 before
# parsing fixes SERVEME-254.
module PaypalResponseEncodingFix
  extend T::Sig

  sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
  def format_response(payload)
    response = payload[:response]
    if response.body && response.body.encoding == Encoding::ASCII_8BIT
      response.body.force_encoding(Encoding::UTF_8)
    end
    super
  end
end
PayPal::SDK::Core::API::REST.prepend(PaypalResponseEncodingFix)
