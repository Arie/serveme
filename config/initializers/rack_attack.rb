# typed: strict
# frozen_string_literal: true

module Rack
  class Attack
    extend T::Sig

    MOTD_PATH = %r{\A/reservations/\d+/motd\z}
    MOTD_FAIL2BAN = T.let({ maxretry: 10, findtime: 10.minutes, bantime: 1.hour }.freeze, T::Hash[Symbol, T.untyped])

    class Request
      extend T::Sig

      # Rack's #ip stops at the Cloudflare edge; RemoteIp trusts Cloudflare's ranges.
      sig { returns(String) }
      def remote_ip
        ActionDispatch::Request.new(env).remote_ip.to_s
      end
    end

    sig { params(ip: String).void }
    def self.motd_password_failed!(ip)
      Fail2Ban.filter("motd-#{ip}", MOTD_FAIL2BAN) { true }
    end

    sig { params(ip: String).returns(T::Boolean) }
    def self.motd_banned?(ip)
      Fail2Ban.banned?("motd-#{ip}")
    end

    unless Rails.env.test? || Rails.env.development?
      safelist("server-monitoring") do |req|
        req.path.start_with?("/server-monitoring") && req.post?
      end

      blocklist("motd/password-guessing") do |req|
        req.path.match?(MOTD_PATH) && motd_banned?(req.remote_ip)
      end

      throttle("req/ip", limit: 300, period: 5.minutes, &:remote_ip)
    end
  end
end
