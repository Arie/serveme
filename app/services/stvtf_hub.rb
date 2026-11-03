# typed: true
# frozen_string_literal: true

class StvtfHub
  extend T::Sig

  CACHE_KEY = "stvtf_hub_matches"
  STALLED_AFTER = 15

  class Error < StandardError; end

  class Match
    extend T::Sig

    sig { returns(T::Hash[String, T.untyped]) }
    attr_reader :data

    sig { params(data: T::Hash[String, T.untyped]).void }
    def initialize(data)
      @data = data
    end

    sig { returns(String) }
    def id = data.fetch("id")

    sig { returns(T.nilable(Integer)) }
    def reservation_id = data["reservation"]

    sig { returns(T::Boolean) }
    def demo?
      !!data["pinned"] || !data["demo"].nil?
    end

    sig { returns(T::Boolean) }
    def pasted?
      !demo? && reservation_id.nil?
    end

    sig { returns(T::Boolean) }
    def stalled?
      age = data["data_age"]
      !data["done"] && !age.nil? && age > STALLED_AFTER
    end

    sig { params(team: String).returns(T::Array[T::Hash[String, T.untyped]]) }
    def players(team)
      Array(data["players"]).select { |p| p["team"] == team }
    end

    sig { returns(String) }
    def url
      "#{StvtfToken.base_url}/w/#{id}/"
    end

    sig { returns(String) }
    def overlay_url
      "#{url}overlay"
    end

    sig { params(key: String).returns(T.untyped) }
    def [](key)
      data[key]
    end
  end

  # Errors are cached too, so a hub that is down costs one timeout per refresh.
  sig { returns([ T::Array[Match], T.nilable(String) ]) }
  def self.matches
    return [ [], "stv.tf is not set up in this region" ] unless StvtfToken.enabled?

    data, error = Rails.cache.fetch(CACHE_KEY, expires_in: 10.seconds) do
      [ fetch, nil ]
    rescue Error, Faraday::Error, JSON::ParserError => e
      [ [], e.message ]
    end
    [ data.map { |m| Match.new(m) }, error ]
  end

  sig { returns(T::Array[T::Hash[String, T.untyped]]) }
  def self.fetch
    response = connection.get("matches") do |req|
      req.headers["Authorization"] = "Bearer #{StvtfToken.list_token}"
    end
    raise Error, "stv.tf answered #{response.status}" unless response.success?

    Array(JSON.parse(response.body)["matches"])
  end

  sig { returns(Faraday::Connection) }
  def self.connection
    Faraday.new(url: "#{StvtfToken.base_url}/") do |f|
      f.options.timeout = 3
      f.options.open_timeout = 2
    end
  end
  private_class_method :fetch, :connection
end
