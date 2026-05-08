# typed: true
# frozen_string_literal: true

class DockerHostImagePullWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: "default"

  DOCKERHUB_IMAGE = "serveme/tf2-cloud-server:latest"

  def perform(docker_host_id = nil)
    if docker_host_id
      pull_image_on_host(DockerHost.find(docker_host_id))
    else
      DockerHost.active.find_each do |host|
        DockerHostImagePullWorker.perform_async(host.id)
      end
    end
  end

  private

  def pull_image_on_host(host)
    opts = { timeout: 5, keepalive: true, keepalive_interval: 5, keepalive_maxcount: 2, bind_address: "0.0.0.0", port: host.ssh_port }
    if host.provider?
      key_data = Rails.application.credentials.dig(:cloud_servers, :ssh_private_key)
      if key_data.present?
        opts[:key_data] = [ key_data ]
        opts[:keys_only] = true
      end
      opts[:verify_host_key] = :never
    end
    Net::SSH.start(host.hostname, host.ssh_user, **opts) do |ssh|
      output = ssh.exec!("docker pull #{DOCKERHUB_IMAGE}")
      Rails.logger.info "DockerHostImagePullWorker: Pulled on #{host.hostname}: #{output&.lines&.last&.strip}"
      prune_output = ssh.exec!("docker image prune -f")
      Rails.logger.info "DockerHostImagePullWorker: Pruned on #{host.hostname}: #{prune_output&.strip}"
    end
  end
end
