# typed: true
# frozen_string_literal: true

class DockerImagePollWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "default"

  DIGEST_SETTING_KEY = "docker_image_digest"

  def perform
    return if DockerHost.active.none?

    client = DockerImageRegistryClient.new
    sync_digest(client)
    sync_version(client)
  end

  private

  def sync_digest(client)
    remote_digest = client.fetch_digest
    return unless remote_digest

    local_digest = SiteSetting.get(DIGEST_SETTING_KEY)
    return if local_digest == remote_digest

    Rails.logger.info "DockerImagePollWorker: New image digest detected (#{remote_digest}), queuing pull on all hosts"
    SiteSetting.set(DIGEST_SETTING_KEY, remote_digest)
    DockerHostImagePullWorker.perform_async
  end

  # Self-healing backstop: keeps the recorded image version in sync with the
  # registry in case the cross-region build notification was missed.
  def sync_version(client)
    remote_version = client.fetch_latest_version_tag
    return unless remote_version

    local_version = SiteSetting.get(DockerImageReadiness::VERSION_SETTING_KEY)
    return if local_version.present? && local_version.to_i >= remote_version.to_i

    Rails.logger.info "DockerImagePollWorker: Recording image version #{remote_version}"
    SiteSetting.set(DockerImageReadiness::VERSION_SETTING_KEY, remote_version)
  end
end
