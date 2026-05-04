# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe DockerImageRegistryClient do
  let(:client) { described_class.new }
  let(:digest) { "sha256:abc123" }

  around do |example|
    VCR.turned_off do
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end
  end

  describe "#fetch_digest" do
    it "returns the docker-content-digest header on success" do
      stub_request(:get, /auth\.docker\.io/).to_return(status: 200, body: { "token" => "t" }.to_json)
      stub_request(:head, /registry-1\.docker\.io/).to_return(
        status: 200, headers: { "docker-content-digest" => digest }
      )

      expect(client.fetch_digest).to eq(digest)
    end

    it "returns nil when the auth token request fails" do
      stub_request(:get, /auth\.docker\.io/).to_return(status: 500)

      expect(client.fetch_digest).to be_nil
    end

    it "returns nil when the registry raises" do
      stub_request(:get, /auth\.docker\.io/).to_return(status: 200, body: { "token" => "t" }.to_json)
      stub_request(:head, /registry-1\.docker\.io/).to_raise(Faraday::ConnectionFailed.new("nope"))

      expect(client.fetch_digest).to be_nil
    end
  end
end
