# typed: false
# frozen_string_literal: true

class FraudlogixService
  BASE_URL = "https://iplist.fraudlogix.com/v5"
  MONTHLY_QUOTA = 1000

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
    "fraudlogix_monthly_usage:#{Date.current.strftime('%Y-%m')}"
  end

  def check(ip)
    raise QuotaExceededError if self.class.quota_exceeded?

    response = make_request(ip)
    increment_quota

    is_residential_proxy = detect_residential_proxy(response)

    IpLookup.create!(
      ip: ip,
      is_proxy: response["Proxy"] || false,
      is_residential_proxy: is_residential_proxy,
      fraud_score: risk_score_to_number(response["RiskScore"]),
      connection_type: response["ConnectionType"],
      isp: response["ISP"],
      country_code: response["CountryCode"],
      raw_response: response
    )
  end

  private

  def detect_residential_proxy(response)
    return true if response["Proxy"] == true
    return true if %w[High Extreme].include?(response["RiskScore"])

    false
  end

  def risk_score_to_number(risk_score)
    case risk_score
    when "Low" then 25
    when "Medium" then 50
    when "High" then 75
    when "Extreme" then 100
    else 0
    end
  end

  def make_request(ip)
    response = HTTP.timeout(10)
      .headers("x-api-key" => api_key, "Content-Type" => "application/json")
      .get("#{BASE_URL}?ip=#{ip}")

    raise ApiError, "HTTP #{response.status}" unless response.status.success?

    JSON.parse(response.body.to_s)
  end

  def increment_quota
    key = self.class.quota_key
    current = Rails.cache.read(key).to_i
    Rails.cache.write(key, current + 1, expires_in: 45.days)
  end

  def api_key
    Rails.application.credentials.dig(:fraudlogix, :api_key) || ENV["FRAUDLOGIX_API_KEY"]
  end
end
