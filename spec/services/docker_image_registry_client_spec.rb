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

  describe "#fetch_latest_version_tag" do
    it "returns the highest numeric tag" do
      stub_request(:get, /auth\.docker\.io/).to_return(status: 200, body: { "token" => "t" }.to_json)
      stub_request(:get, %r{registry-1\.docker\.io/v2/.+/tags/list}).to_return(
        status: 200, body: { "tags" => [ "latest", "9876000", "9876543" ] }.to_json
      )

      expect(client.fetch_latest_version_tag).to eq("9876543")
    end

    it "ignores non-numeric tags" do
      stub_request(:get, /auth\.docker\.io/).to_return(status: 200, body: { "token" => "t" }.to_json)
      stub_request(:get, %r{registry-1\.docker\.io/v2/.+/tags/list}).to_return(
        status: 200, body: { "tags" => [ "latest", "edge", "beta" ] }.to_json
      )

      expect(client.fetch_latest_version_tag).to be_nil
    end

    it "returns nil when the auth token request fails" do
      stub_request(:get, /auth\.docker\.io/).to_return(status: 500)

      expect(client.fetch_latest_version_tag).to be_nil
    end

    it "returns nil when the registry raises" do
      stub_request(:get, /auth\.docker\.io/).to_return(status: 200, body: { "token" => "t" }.to_json)
      stub_request(:get, %r{registry-1\.docker\.io/v2/.+/tags/list}).to_raise(Faraday::ConnectionFailed.new("nope"))

      expect(client.fetch_latest_version_tag).to be_nil
    end
  end

  it "fetches the auth token only once across multiple registry calls" do
    stub_request(:get, /auth\.docker\.io/).to_return(status: 200, body: { "token" => "t" }.to_json)
    stub_request(:head, /registry-1\.docker\.io/).to_return(status: 200, headers: { "docker-content-digest" => digest })
    stub_request(:get, %r{registry-1\.docker\.io/v2/.+/tags/list}).to_return(status: 200, body: { "tags" => [ "9876543" ] }.to_json)

    client.fetch_digest
    client.fetch_latest_version_tag

    expect(WebMock).to have_requested(:get, /auth\.docker\.io/).once
  end
end
