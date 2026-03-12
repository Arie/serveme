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
    Net::SSH.start(host.ip, nil, timeout: 5, keepalive: true, keepalive_interval: 5, keepalive_maxcount: 2) do |ssh|
      output = ssh.exec!("docker pull #{DOCKERHUB_IMAGE}")
      Rails.logger.info "DockerHostImagePullWorker: Pulled on #{host.ip}: #{output&.lines&.last&.strip}"
    end
  end
end
