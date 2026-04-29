# typed: false
# frozen_string_literal: true

require "spec_helper"

describe BuildWebsocketEchoImageWorker do
  let(:worker) { described_class.new }
  let(:redis) { instance_double(Redis) }
  let(:ok) { instance_double(Process::Status, success?: true, exitstatus: 0) }

  before do
    stub_const("SITE_HOST", "serveme.tf")
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(redis).to receive(:set).and_return(true)
    allow(redis).to receive(:del)
    allow(Open3).to receive(:capture2e).and_return([ "", ok ])
  end

  it "builds with --pull and pushes :latest to Docker Hub" do
    expect(Open3).to receive(:capture2e).with("docker", "build", "--pull", "-t", "serveme/websocket-echo:latest", described_class::DOCKER_DIR).and_return([ "", ok ])
    expect(Open3).to receive(:capture2e).with("docker", "push", "serveme/websocket-echo:latest").and_return([ "", ok ])
    worker.perform
  end

  it "skips when not on the EU region" do
    stub_const("SITE_HOST", "na.serveme.tf")
    expect(Open3).not_to receive(:capture2e)
    worker.perform
  end

  it "skips when the lock can't be acquired" do
    allow(redis).to receive(:set).and_return(false)
    expect(Open3).not_to receive(:capture2e)
    worker.perform
  end

  it "raises with output tail when docker build fails" do
    fail_status = instance_double(Process::Status, success?: false, exitstatus: 1)
    expect(Open3).to receive(:capture2e).with("docker", "build", "--pull", "-t", anything, anything).and_return([ "boom\n", fail_status ])
    expect(Open3).not_to receive(:capture2e).with("docker", "push", anything)
    expect { worker.perform }.to raise_error(RuntimeError, /docker build --pull failed.*boom/m)
  end

  it "releases the lock after completion" do
    expect(redis).to receive(:del).with(described_class::LOCK_KEY)
    worker.perform
  end
end
