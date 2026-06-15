# typed: true
# frozen_string_literal: true

class FraudlogixService
  extend T::Sig

  BASE_URL = "https://iplist.fraudlogix.com/v5"

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

  sig { params(response: T.untyped).returns(T::Boolean) }
  def detect_residential_proxy(response)
    return true if response["Proxy"] == true
    return true if response["VPN"] == true
    return true if response["TOR"] == true
    return true if response["DataCenter"] == true

    false
  end

  sig { params(risk_score: T.untyped).returns(Integer) }
  def risk_score_to_number(risk_score)
    case risk_score
    when "Low" then 25
    when "Medium" then 50
    when "High" then 75
    when "Extreme" then 100
    else 0
    end
  end

  sig { params(ip: T.nilable(String)).returns(T::Hash[String, T.untyped]) }
  def make_request(ip)
    response = HTTP.timeout(10)
      .headers("x-api-key" => api_key, "Content-Type" => "application/json")
      .get("#{BASE_URL}?ip=#{ip}")

    # Fraudlogix returns 429 when rate limited
    if response.status.code == 429
      raise QuotaExceededError, "Rate limit exceeded"
    end

    # Check for quota/limit errors in response body
    if response.status.code == 401 || response.status.code == 403
      body = response.body.to_s
      if body.include?("limit") || body.include?("quota") || body.include?("exceeded")
        raise QuotaExceededError, body
      end
    end

    raise ApiError, "HTTP #{response.status}" unless response.status.success?

    json = JSON.parse(response.body.to_s)

    # Check for error message in JSON response
    if json["error"].to_s.downcase.include?("limit") || json["error"].to_s.downcase.include?("quota")
      raise QuotaExceededError, json["error"]
    end

    json
  end

  sig { returns(T.nilable(String)) }
  def api_key
    Rails.application.credentials.dig(:fraudlogix, :api_key) || ENV["FRAUDLOGIX_API_KEY"]
  end
end
