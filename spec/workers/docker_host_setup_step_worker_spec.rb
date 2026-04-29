# typed: false
# frozen_string_literal: true

require "spec_helper"

describe DockerHostSetupStepWorker do
  let(:docker_host) { create(:docker_host) }
  let(:service) { instance_double(DockerHostSetupService) }
  let(:result) { { success: true, message: "ok" } }

  before do
    allow(DockerHostSetupService).to receive(:new).with(docker_host).and_return(service)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  it "raises on an unknown step" do
    expect { described_class.new.perform(docker_host.id, "evil-step") }.to raise_error(ArgumentError, /unknown step/)
  end

  {
    "create_vm" => :create_vm,
    "dns" => :check_dns,
    "ssh" => :check_ssh,
    "provision" => :provision_host,
    "ssl" => :check_ssl,
    "pull_image" => :pull_image
  }.each do |step, method|
    it "dispatches the #{step.inspect} step to DockerHostSetupService##{method}" do
      allow(service).to receive(method).and_return(result)
      described_class.new.perform(docker_host.id, step)
      expect(service).to have_received(method)
    end
  end

  it "broadcasts the result, controls, status, and logs to the host stream" do
    allow(service).to receive(:provision_host).and_return(result)
    described_class.new.perform(docker_host.id, "provision")

    stream = "docker_host_setup_#{docker_host.id}"
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(stream, hash_including(target: "step-provision-result"))
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(stream, hash_including(target: "step-provision-controls"))
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(stream, hash_including(target: "setup-status"))
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(stream, hash_including(target: "setup-logs"))
  end
end
