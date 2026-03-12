# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe CloudImageBuildWorker do
  let(:worker) { described_class.new }
  let(:version) { 9876543 }
  let(:redis) { instance_double(Redis) }

  around do |example|
    VCR.turned_off do
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end
  end

  before do
    stub_const("SITE_HOST", "serveme.tf")
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(redis).to receive(:set).and_return(true)
    allow(redis).to receive(:del)
    allow(Open3).to receive(:capture2e).and_return([ "", instance_double(Process::Status, success?: true, exitstatus: 0) ])
    allow(Rails.application.credentials).to receive(:dig).with(:serveme, anything).and_return(nil)
  end

  describe "#perform" do
    it "builds and pushes the Docker image" do
      expect(Open3).to receive(:capture2e).with(/docker build --pull/).and_return([ "", instance_double(Process::Status, success?: true, exitstatus: 0) ])
      expect(Open3).to receive(:capture2e).with(/docker push/).and_return([ "", instance_double(Process::Status, success?: true, exitstatus: 0) ])

      worker.perform(version)
    end

    it "skips if not on EU (serveme.tf)" do
      stub_const("SITE_HOST", "na.serveme.tf")

      expect(Open3).not_to receive(:capture2e)

      worker.perform(version)
    end

    it "skips if lock cannot be acquired" do
      allow(redis).to receive(:set).and_return(false)

      expect(Open3).not_to receive(:capture2e)

      worker.perform(version)
    end

    it "raises with output tail if docker build fails so Sidekiq retries" do
      expect(Open3).to receive(:capture2e).with(/docker build/).and_return([ "Error! App '232250' state is 0x426\n", instance_double(Process::Status, success?: false, exitstatus: 1) ])
      expect(Open3).not_to receive(:capture2e).with(/docker push/)

      expect { worker.perform(version) }.to raise_error(RuntimeError, /docker build --pull.*failed.*0x426/m)
    end

    it "releases the lock after completion" do
      expect(redis).to receive(:del).with("cloud_image_build")

      worker.perform(version)
    end

    it "notifies other regions after successful push" do
      allow(Rails.application.credentials).to receive(:dig).with(:serveme, anything).and_return("test-api-key")

      %w[na.serveme.tf sea.serveme.tf au.serveme.tf].each do |host|
        stub_request(:post, "https://direct.#{host}/api/docker_image_updates")
          .with(headers: { "Authorization" => "Bearer test-api-key" })
          .to_return(status: 200)
      end

      worker.perform(version)

      expect(WebMock).to have_requested(:post, "https://direct.na.serveme.tf/api/docker_image_updates")
      expect(WebMock).to have_requested(:post, "https://direct.sea.serveme.tf/api/docker_image_updates")
      expect(WebMock).to have_requested(:post, "https://direct.au.serveme.tf/api/docker_image_updates")
    end

    it "continues notifying other regions when one fails" do
      allow(Rails.application.credentials).to receive(:dig).with(:serveme, anything).and_return("test-api-key")

      stub_request(:post, "https://direct.na.serveme.tf/api/docker_image_updates").to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      stub_request(:post, "https://direct.sea.serveme.tf/api/docker_image_updates").to_return(status: 200)
      stub_request(:post, "https://direct.au.serveme.tf/api/docker_image_updates").to_return(status: 200)

      worker.perform(version)

      expect(WebMock).to have_requested(:post, "https://direct.sea.serveme.tf/api/docker_image_updates")
      expect(WebMock).to have_requested(:post, "https://direct.au.serveme.tf/api/docker_image_updates")
    end
  end
end
