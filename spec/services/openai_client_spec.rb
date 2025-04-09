# typed: false

require 'spec_helper'

RSpec.describe OpenaiClient do
  let(:openai_client) { instance_double(::OpenAI::Client) }
  let(:parameters) { { model: "test-model", messages: [] } }
  let(:response) { { "choices" => [ { "message" => { "content" => "test" } } ] } }
  let(:api_key) { "test-api-key" }

  before(:each) do
    described_class.instance_variable_set(:@instance, nil)
    allow(Rails.application.credentials).to receive(:dig).with(:ai_provider).and_return(:openai)
    allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(api_key)
    allow(::OpenAI::Client).to receive(:new).with(
      access_token: api_key,
      uri_base: "https://api.openai.com/",
      request_timeout: 15,
      log_errors: true
    ).and_return(openai_client)
  end

  describe '.chat' do
    it 'delegates to the OpenAI client instance' do
      expect(openai_client).to receive(:chat).with(parameters: parameters).and_return(response)
      expect(described_class.chat(parameters)).to eq(response)
    end

    it 'reuses the same client instance' do
      first_instance = described_class.instance
      second_instance = described_class.instance
      expect(::OpenAI::Client).to have_received(:new).once
      expect(first_instance).to eq(second_instance)
    end

    it 'uses the API key from Rails credentials' do
      described_class.instance
      expect(Rails.application.credentials).to have_received(:dig).with(:openai, :api_key)
    end
  end
end
