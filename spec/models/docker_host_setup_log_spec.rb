# typed: false
# frozen_string_literal: true

require "spec_helper"

describe DockerHostSetupLog do
  let(:docker_host) { create(:docker_host) }

  it "belongs to a docker_host and exposes a human label" do
    log = docker_host.setup_logs.create!(step: "install_compose_services", success: true, output: "ok\n", exit_status: 0)
    expect(log.label).to eq("Compose services (Caddy + websocket-echo)")
  end

  it "falls back to the raw step name when no label is registered" do
    log = docker_host.setup_logs.create!(step: "custom_step", success: true)
    expect(log.label).to eq("custom_step")
  end

  it "orders most recent first via .recent" do
    older = docker_host.setup_logs.create!(step: "install_docker", success: true, created_at: 2.minutes.ago)
    newer = docker_host.setup_logs.create!(step: "install_docker", success: false, created_at: 1.minute.ago)
    expect(docker_host.setup_logs.recent.to_a).to eq([ newer, older ])
  end
end
