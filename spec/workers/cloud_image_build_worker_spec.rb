# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudImageBuildWorker do
  let(:worker) { described_class.new }
  let(:version) { 9876543 }
  let(:redis) { instance_double(Redis) }

  before do
    stub_const("SITE_HOST", "serveme.tf")
    allow(Rails.application.credentials).to receive(:dig).with(:cloud_servers, :ghcr_token).and_return("fake-token")
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(redis).to receive(:set).and_return(true)
    allow(redis).to receive(:del)
    allow(worker).to receive(:system).and_return(true)
  end

  describe "#perform" do
    it "builds and pushes the Docker image" do
      expect(worker).to receive(:system).with(/docker login/).and_return(true)
      expect(worker).to receive(:system).with(/docker build --pull/).and_return(true)
      expect(worker).to receive(:system).with(/docker push/).and_return(true)

      worker.perform(version)
    end

    it "skips if not on EU (serveme.tf)" do
      stub_const("SITE_HOST", "na.serveme.tf")

      expect(worker).not_to receive(:system)

      worker.perform(version)
    end

    it "skips if lock cannot be acquired" do
      allow(redis).to receive(:set).and_return(false)

      expect(worker).not_to receive(:system)

      worker.perform(version)
    end

    it "skips if ghcr_token is not configured" do
      allow(Rails.application.credentials).to receive(:dig).with(:cloud_servers, :ghcr_token).and_return(nil)

      expect(worker).not_to receive(:system)

      worker.perform(version)
    end

    it "stops if docker build fails" do
      expect(worker).to receive(:system).with(/docker login/).and_return(true)
      expect(worker).to receive(:system).with(/docker build/).and_return(false)
      expect(worker).not_to receive(:system).with(/docker push/)

      worker.perform(version)
    end

    it "releases the lock after completion" do
      expect(redis).to receive(:del).with("cloud_image_build")

      worker.perform(version)
    end
  end
end
