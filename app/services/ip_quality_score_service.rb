# typed: true
# frozen_string_literal: true

class IpQualityScoreService
  extend T::Sig

  BASE_URL = "https://www.ipqualityscore.com/api/json/ip"
  FRAUD_SCORE_THRESHOLD = 90

  class QuotaExceededError < StandardError; end
  class ApiError < StandardError; end

  sig { params(ip: T.nilable(String)).returns(IpLookup) }
  def self.check(ip)
    new.check(ip)
  end

  sig { params(ip: T.nilable(String)).returns(IpLookup) }
  def check(ip)
    response = make_request(ip)

    is_residential_proxy = detect_residential_proxy(response)

    IpLookup.create!(
      ip: ip,
      is_proxy: response["proxy"] || false,
      is_residential_proxy: is_residential_proxy,
      fraud_score: response["fraud_score"],
      connection_type: response["connection_type"],
      isp: response["ISP"],
      country_code: response["country_code"],
      raw_response: response
    )
  end

  private

  sig { params(response: T.untyped).returns(T::Boolean) }
  def detect_residential_proxy(response)
    return true if response["proxy"] == true
    return true if response["vpn"] == true
    return true if response["tor"] == true
    return true if response["active_vpn"] == true
    return true if response["active_tor"] == true

    false
  end

  sig { params(ip: T.nilable(String)).returns(T::Hash[String, T.untyped]) }
  def make_request(ip)
    url = "#{BASE_URL}/#{api_key}/#{ip}?strictness=1"
    response = HTTP.timeout(10).get(url)

    raise ApiError, "HTTP #{response.status}" unless response.status.success?

    json = JSON.parse(response.body.to_s)

    if json["message"].to_s.include?("exceeded")
      raise QuotaExceededError, json["message"]
    end

    raise ApiError, json["message"] unless json["success"]

    json
  end

  sig { returns(T.nilable(String)) }
  def api_key
    Rails.application.credentials.dig(:ipqs, :api_key) || ENV["IPQS_API_KEY"]
  end
end
