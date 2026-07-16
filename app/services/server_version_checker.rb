# typed: strict
# frozen_string_literal: true

# Resolves the latest available TF2 version (fleet-wide, via the Steam API) and
# tells whether a given server is behind it. Extracted from Server to keep the
# model focused on persistence; Server delegates #version/#outdated? and the
# class-level .latest_version/.fetch_latest_version here.
class ServerVersionChecker
  extend T::Sig

  CACHE_KEY = "latest_server_version"

  class << self
    extend T::Sig

    sig { returns(T.nilable(Integer)) }
    def latest_version
      # skip_nil so a failed Steam lookup doesn't cache "unknown" for 5 minutes:
      # callers treat nil as "every server is outdated", so we'd rather retry.
      Rails.cache.fetch(CACHE_KEY, expires_in: 5.minutes, skip_nil: true) do
        fetch_latest_version
      end
    end

    sig { returns(T.nilable(Integer)) }
    def fetch_latest_version
      return 100_000_000 if Rails.env == "test"

      response = Faraday.new(url: "http://api.steampowered.com").get("ISteamApps/UpToDateCheck/v1?appid=440&version=0") do |req|
        req.options.timeout = 5
        req.options.open_timeout = 2
      end
      return unless response.success?

      json = JSON.parse(response.body)
      # Steam answers 200 with no required_version when the lookup fails. Plain
      # #to_i would turn that into 0, which reads as a valid (truthy) version and
      # sends bogus versions downstream, so treat anything non-positive as unknown.
      version = json.dig("response", "required_version").to_i
      version.positive? ? version : nil
    rescue SteamCondenser::Error::Timeout, Net::ReadTimeout, Faraday::TimeoutError => e
      Rails.logger.info "Steam API timeout when fetching latest version: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Failed to fetch latest version: #{e.message}"
      nil
    end
  end

  sig { params(server: Server).void }
  def initialize(server)
    @server = server
    @current = T.let(nil, T.nilable(Integer))
  end

  sig { returns(T.nilable(Integer)) }
  def current
    @current ||= /Network\ PatchVersion:\s+(\d+)/ =~ @server.rcon_exec("version").to_s && Regexp.last_match(1).to_i
  end

  sig { returns(T::Boolean) }
  def outdated?
    return false if @server.team_comtress_server?

    current != self.class.latest_version
  end
end
