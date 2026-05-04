# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe CloudImageBuildWorker do
  let(:worker) { described_class.new }
  let(:version) { "9876543" }
  let(:build) { CloudImageBuild.create!(version: version) }
  let(:redis) { instance_double(Redis) }
  let(:success_status) { instance_double(Process::Status, success?: true, exitstatus: 0) }
  let(:failure_status) { instance_double(Process::Status, success?: false, exitstatus: 1) }

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
    allow(Rails.application.credentials).to receive(:dig).with(:serveme, anything).and_return(nil)
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(DockerHostImagePullWorker).to receive(:perform_async)
    stub_streamed_command([ "docker", "build", "--build-arg", "TF2_VERSION=#{version}", "-t", "serveme/tf2-cloud-server:latest", CloudImageBuildWorker::DOCKER_DIR ], success_status, "build line\n")
    stub_streamed_command([ "docker", "push", "serveme/tf2-cloud-server:latest" ], success_status, "push line\n")
    allow(Open3).to receive(:capture2e).with("docker", "inspect", anything, anything).and_return([ "serveme/tf2-cloud-server@sha256:newdigest\n", success_status ])
  end

  describe "#perform" do
    it "marks the build succeeded and records the digest" do
      worker.perform(build.id)

      build.reload
      expect(build.status).to eq("succeeded")
      expect(build.started_at).to be_present
      expect(build.finished_at).to be_present
      expect(build.digest).to eq("sha256:newdigest")
      expect(build.current_phase).to be_nil
    end

    it "appends streamed output to the build" do
      worker.perform(build.id)
      expect(build.reload.output).to include("build line").and include("push line")
    end

    it "passes --pull when force_pull is true" do
      build.update!(force_pull: true)
      stub_streamed_command([ "docker", "build", "--pull", "--build-arg", "TF2_VERSION=#{version}", "-t", "serveme/tf2-cloud-server:latest", CloudImageBuildWorker::DOCKER_DIR ], success_status, "")

      worker.perform(build.id)
      expect(build.reload.status).to eq("succeeded")
    end

    it "is idempotent: skips already-finished builds" do
      build.update!(status: "succeeded", finished_at: Time.current)
      expect(Open3).not_to receive(:popen2e)

      worker.perform(build.id)
    end

    it "marks build as skipped_locked when the redis lock is held" do
      allow(redis).to receive(:set).and_return(false)
      expect(redis).not_to receive(:del)
      expect(Open3).not_to receive(:popen2e)

      worker.perform(build.id)

      build.reload
      expect(build.status).to eq("skipped_locked")
      expect(build.finished_at).to be_present
      expect(build.output).to include("Another build was already running")
    end

    it "marks build as failed and records exception output when docker build fails" do
      stub_streamed_command([ "docker", "build", "--build-arg", "TF2_VERSION=#{version}", "-t", "serveme/tf2-cloud-server:latest", CloudImageBuildWorker::DOCKER_DIR ], failure_status, "Error! App state\n")

      expect { worker.perform(build.id) }.not_to raise_error

      build.reload
      expect(build.status).to eq("failed")
      expect(build.output).to include("Error! App state")
      expect(build.output).to include("[ERROR]")
    end

    it "releases the redis lock after completion" do
      expect(redis).to receive(:del).with("cloud_image_build")
      worker.perform(build.id)
    end

    it "queues DockerHostImagePullWorker on success" do
      expect(DockerHostImagePullWorker).to receive(:perform_async)
      worker.perform(build.id)
    end

    it "writes new digest to SiteSetting on success" do
      worker.perform(build.id)
      expect(SiteSetting.get(DockerImagePollWorker::DIGEST_SETTING_KEY)).to eq("sha256:newdigest")
    end

    it "notifies other regions after successful push" do
      allow(Rails.application.credentials).to receive(:dig).with(:serveme, anything).and_return("test-api-key")
      %w[na.serveme.tf sea.serveme.tf au.serveme.tf].each do |host|
        stub_request(:post, "https://direct.#{host}/api/docker_image_updates").to_return(status: 200)
      end

      worker.perform(build.id)

      expect(WebMock).to have_requested(:post, "https://direct.na.serveme.tf/api/docker_image_updates")
      expect(WebMock).to have_requested(:post, "https://direct.sea.serveme.tf/api/docker_image_updates")
      expect(WebMock).to have_requested(:post, "https://direct.au.serveme.tf/api/docker_image_updates")
    end

    it "continues notifying other regions when one fails" do
      allow(Rails.application.credentials).to receive(:dig).with(:serveme, anything).and_return("test-api-key")
      stub_request(:post, "https://direct.na.serveme.tf/api/docker_image_updates").to_raise(Faraday::ConnectionFailed.new("nope"))
      stub_request(:post, "https://direct.sea.serveme.tf/api/docker_image_updates").to_return(status: 200)
      stub_request(:post, "https://direct.au.serveme.tf/api/docker_image_updates").to_return(status: 200)

      worker.perform(build.id)

      expect(WebMock).to have_requested(:post, "https://direct.sea.serveme.tf/api/docker_image_updates")
      expect(WebMock).to have_requested(:post, "https://direct.au.serveme.tf/api/docker_image_updates")
    end

    it "marks build as failed when broadcast_status raises before lock acquisition" do
      call_count = 0
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) do
        call_count += 1
        raise(RuntimeError, "broadcast down") if call_count == 1
        nil
      end
      expect(redis).not_to receive(:del)

      expect { worker.perform(build.id) }.not_to raise_error

      build.reload
      expect(build.status).to eq("failed")
      expect(build.output).to include("broadcast down")
    end

    it "marks build as failed when acquire_lock raises" do
      allow(redis).to receive(:set).and_raise(Redis::CannotConnectError, "redis down")
      expect(redis).not_to receive(:del)

      expect { worker.perform(build.id) }.not_to raise_error

      build.reload
      expect(build.status).to eq("failed")
      expect(build.output).to include("redis down")
    end
  end

  # Helper: stubs Open3.popen2e to yield scripted lines and a wait_thread with the given status.
  define_method(:stub_streamed_command) do |command, status, output|
    fake_stdout = StringIO.new(output)
    fake_thread = instance_double(Thread, value: status)
    allow(Open3).to receive(:popen2e).with(*command).and_yield(StringIO.new, fake_stdout, fake_thread)
  end
end
