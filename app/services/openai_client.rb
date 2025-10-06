# typed: true

require "openai"

class OpenaiClient
  PROVIDERS = {
    openai: {
      uri_base: "https://api.openai.com/",
      default_model: "gpt-5-mini"
    },
    deepseek: {
      uri_base: "https://api.deepseek.com/v1/",
      default_model: "deepseek-chat"
    },
    gemini: {
      uri_base: "https://generativelanguage.googleapis.com/v1beta/openai/",
      default_model: "gemini-2.5-flash-preview-04-17"
    }
  }

  def self.provider
    Rails.application.credentials.dig(:ai_provider)&.to_sym || :openai
  end

  def self.instance
    @instance ||= ::OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(provider, :api_key),
      uri_base: PROVIDERS.dig(provider, :uri_base),
      request_timeout: 30,
      log_errors: true
    )
  end

  def self.chat(parameters)
    parameters[:model] ||= PROVIDERS.dig(provider, :default_model)
    instance.chat(parameters: parameters)
  end
end
