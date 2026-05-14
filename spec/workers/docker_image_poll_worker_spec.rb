# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe DockerImagePollWorker do
  let(:worker) { described_class.new }
  let(:token_response) { { "token" => "test-token" }.to_json }
  let(:digest) { "sha256:abc123" }

  around do |example|
    VCR.turned_off do
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end
  end

  define_method(:stub_registry) do |digest:, tags: [ "latest" ]|
    stub_request(:get, /auth\.docker\.io/).to_return(status: 200, body: token_response)
    stub_request(:head, /registry-1\.docker\.io/).to_return(
      status: 200, headers: { "docker-content-digest" => digest }
    )
    stub_request(:get, %r{registry-1\.docker\.io/v2/.+/tags/list}).to_return(
      status: 200, body: { "tags" => tags }.to_json
    )
  end

  describe "#perform" do
    it "skips when no active docker hosts" do
      allow(DockerHost).to receive(:active).and_return(DockerHost.none)

      expect(Faraday).not_to receive(:get)

      worker.perform
    end

    it "queues pull worker when digest has changed" do
      create(:docker_host)
      SiteSetting.set("docker_image_digest", nil)
      stub_registry(digest: digest)

      expect(DockerHostImagePullWorker).to receive(:perform_async)

      worker.perform
    end

    it "does not queue pull worker when digest is unchanged" do
      create(:docker_host)
      SiteSetting.set("docker_image_digest", digest)
      stub_registry(digest: digest)

      expect(DockerHostImagePullWorker).not_to receive(:perform_async)

      worker.perform
    end

    it "handles registry errors gracefully" do
      create(:docker_host)

      stub_request(:get, /auth\.docker\.io/).to_return(status: 500)

      expect(DockerHostImagePullWorker).not_to receive(:perform_async)
      expect { worker.perform }.not_to raise_error
    end

    it "records the latest version tag from the registry" do
      create(:docker_host)
      SiteSetting.set("docker_image_digest", digest)
      SiteSetting.set(DockerImageReadiness::VERSION_SETTING_KEY, nil)
      stub_registry(digest: digest, tags: [ "latest", "9876543" ])

      worker.perform

      expect(SiteSetting.get(DockerImageReadiness::VERSION_SETTING_KEY)).to eq("9876543")
    end

    it "does not move the recorded version backwards" do
      create(:docker_host)
      SiteSetting.set("docker_image_digest", digest)
      SiteSetting.set(DockerImageReadiness::VERSION_SETTING_KEY, "9999999")
      stub_registry(digest: digest, tags: [ "latest", "9876543" ])

      worker.perform

      expect(SiteSetting.get(DockerImageReadiness::VERSION_SETTING_KEY)).to eq("9999999")
    end

    it "records the version even when the digest is unchanged" do
      create(:docker_host)
      SiteSetting.set("docker_image_digest", digest)
      SiteSetting.set(DockerImageReadiness::VERSION_SETTING_KEY, nil)
      stub_registry(digest: digest, tags: [ "latest", "9876543" ])

      worker.perform

      expect(SiteSetting.get(DockerImageReadiness::VERSION_SETTING_KEY)).to eq("9876543")
    end
  end
end
