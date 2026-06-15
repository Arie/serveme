# typed: true
# frozen_string_literal: true

class ProxyDetectionService
  extend T::Sig

  class AllProvidersExhaustedError < StandardError; end

  PROVIDERS = [
    { service: IpQualityScoreService, name: "IPQS" },
    { service: FraudlogixService, name: "Fraudlogix" }
  ].freeze

  sig { params(ip: T.nilable(String)).returns(IpLookup) }
  def self.check(ip)
    new.check(ip)
  end

  sig { params(ip: T.nilable(String)).returns(IpLookup) }
  def check(ip)
    errors = []

    PROVIDERS.each do |provider|
      result = try_provider(provider, ip)
      return result if result

    rescue IpQualityScoreService::QuotaExceededError, FraudlogixService::QuotaExceededError
      Rails.logger.info "[ProxyDetection] #{provider[:name]} quota exceeded, trying next provider"
      errors << "#{provider[:name]}: quota exceeded"
    rescue IpQualityScoreService::ApiError, FraudlogixService::ApiError => e
      Rails.logger.warn "[ProxyDetection] #{provider[:name]} API error: #{e.message}, trying next provider"
      errors << "#{provider[:name]}: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "[ProxyDetection] #{provider[:name]} unexpected error: #{e.message}, trying next provider"
      errors << "#{provider[:name]}: #{e.message}"
    end

    raise AllProvidersExhaustedError, "All providers failed: #{errors.join('; ')}"
  end

  private

  sig { params(provider: T::Hash[Symbol, T.untyped], ip: T.nilable(String)).returns(T.nilable(IpLookup)) }
  def try_provider(provider, ip)
    provider[:service].check(ip)
  end
end
