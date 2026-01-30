# typed: false
# frozen_string_literal: true

class IpQualityScoreService
  BASE_URL = "https://www.ipqualityscore.com/api/json/ip"
  MONTHLY_QUOTA = 1000
  FRAUD_SCORE_THRESHOLD = 90

  class QuotaExceededError < StandardError; end
  class ApiError < StandardError; end

  def self.check(ip)
    new.check(ip)
  end

  def self.quota_exceeded?
    current_usage >= MONTHLY_QUOTA
  end

  def self.current_usage
    Rails.cache.read(quota_key)&.to_i || 0
  end

  def self.quota_key
    "ipqs_monthly_usage:#{Date.current.strftime('%Y-%m')}"
  end

  def check(ip)
    raise QuotaExceededError if self.class.quota_exceeded?

    response = make_request(ip)
    increment_quota

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

  def detect_residential_proxy(response)
    return true if response["fraud_score"].to_i >= FRAUD_SCORE_THRESHOLD
    return true if response["proxy"] && response["connection_type"] == "Residential"

    false
  end

  def make_request(ip)
    url = "#{BASE_URL}/#{api_key}/#{ip}?strictness=1"
    response = HTTP.timeout(10).get(url)

    raise ApiError, "HTTP #{response.status}" unless response.status.success?

    json = JSON.parse(response.body.to_s)
    raise ApiError, json["message"] unless json["success"]

    json
  end

  def increment_quota
    key = self.class.quota_key
    current = Rails.cache.read(key).to_i
    Rails.cache.write(key, current + 1, expires_in: 45.days)
  end

  def api_key
    Rails.application.credentials.dig(:ipqs, :api_key) || ENV["IPQS_API_KEY"]
  end
end
