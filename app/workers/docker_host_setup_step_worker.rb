# typed: true
# frozen_string_literal: true

class DockerHostSetupStepWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0, queue: "default"

  STEPS = %w[create_vm dns ssh provision ssl pull_image].freeze

  def perform(docker_host_id, step)
    raise ArgumentError, "unknown step: #{step}" unless STEPS.include?(step)

    docker_host = DockerHost.find(docker_host_id)
    service = DockerHostSetupService.new(docker_host)
    result = case step
    when "create_vm" then service.create_vm
    when "dns" then service.check_dns
    when "ssh" then service.check_ssh
    when "provision" then service.provision_host
    when "ssl" then service.check_ssl
    when "pull_image" then service.pull_image
    end

    docker_host.reload
    broadcast_step_completion(docker_host, step, result)
  end

  private

  def broadcast_step_completion(docker_host, step, result)
    stream = "docker_host_setup_#{docker_host.id}"

    Turbo::StreamsChannel.broadcast_replace_to(
      stream,
      target: "step-#{step}-result",
      partial: "admin/docker_hosts/step_result",
      locals: { step: step, result: result }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      stream,
      target: "step-#{step}-controls",
      partial: "admin/docker_hosts/step_controls",
      locals: { docker_host: docker_host, step: step, running: false }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      stream,
      target: "setup-status",
      partial: "admin/docker_hosts/setup_status",
      locals: { docker_host: docker_host }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      stream,
      target: "setup-logs",
      partial: "admin/docker_hosts/setup_logs",
      locals: { docker_host: docker_host }
    )
  end
end
