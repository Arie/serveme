# typed: false
# frozen_string_literal: true

class ProxyDetectionService
  class AllProvidersExhaustedError < StandardError; end

  PROVIDERS = [
    { service: FraudlogixService, name: "Fraudlogix" }
  ].freeze

  def self.check(ip)
    new.check(ip)
  end

  def check(ip)
    errors = []

    PROVIDERS.each do |provider|
      result = try_provider(provider, ip)
      return result if result

    rescue provider[:service]::QuotaExceededError
      Rails.logger.info "[ProxyDetection] #{provider[:name]} quota exceeded, trying next provider"
      errors << "#{provider[:name]}: quota exceeded"
    rescue provider[:service]::ApiError => e
      Rails.logger.warn "[ProxyDetection] #{provider[:name]} API error: #{e.message}, trying next provider"
      errors << "#{provider[:name]}: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "[ProxyDetection] #{provider[:name]} unexpected error: #{e.message}, trying next provider"
      errors << "#{provider[:name]}: #{e.message}"
    end

    raise AllProvidersExhaustedError, "All providers failed: #{errors.join('; ')}"
  end

  private

  def try_provider(provider, ip)
    provider[:service].check(ip)
  end
end
