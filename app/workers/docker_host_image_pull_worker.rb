# typed: true
# frozen_string_literal: true

class DockerHostImagePullWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: "default"

  DOCKERHUB_IMAGE = "serveme/tf2-cloud-server:latest"
  # The legacy builder's cache *is* the set of dangling per-step images, so a
  # blanket `docker image prune -f` on the build host throws away the TF2 base
  # (~15GB steamcmd download) and can even delete a running build's stage images.
  # Keep anything recent enough to still serve as cache for the next build.
  BUILD_HOST_PRUNE_AGE = "168h"
  # Superseded versioned tags aren't dangling, so they survive the age-filtered
  # prune above and need removing explicitly to bound disk use on the build host.
  VERSIONED_TAGS_KEPT = 3

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
      cleanup_images(ssh, host)
    end
  end

  def cleanup_images(ssh, host)
    if host.build_host?
      prune_output = ssh.exec!("docker image prune -f --filter until=#{BUILD_HOST_PRUNE_AGE}")
      Rails.logger.info "DockerHostImagePullWorker: Pruned (age-filtered) on #{host.hostname}: #{prune_output&.strip}"
      rmi_output = ssh.exec!(remove_superseded_tags_command)
      Rails.logger.info "DockerHostImagePullWorker: Removed superseded tags on #{host.hostname}: #{rmi_output&.strip}"
    else
      prune_output = ssh.exec!("docker image prune -f")
      Rails.logger.info "DockerHostImagePullWorker: Pruned on #{host.hostname}: #{prune_output&.strip}"
    end
  end

  # `docker images` lists newest first, so keep the head of the list and remove
  # the rest. `:latest` is excluded since it always points at the current build.
  def remove_superseded_tags_command
    image = DOCKERHUB_IMAGE.split(":").first
    "docker images #{image} --format '{{.Tag}}' | grep -v '^latest$' | " \
      "tail -n +#{VERSIONED_TAGS_KEPT + 1} | xargs -r -I{} docker rmi #{image}:{}"
  end
end
