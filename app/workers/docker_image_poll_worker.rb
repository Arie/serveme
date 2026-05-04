# typed: true
# frozen_string_literal: true

class DockerImagePollWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "default"

  DIGEST_SETTING_KEY = "docker_image_digest"

  def perform
    return if DockerHost.active.none?

    remote_digest = DockerImageRegistryClient.new.fetch_digest
    return unless remote_digest

    local_digest = SiteSetting.get(DIGEST_SETTING_KEY)
    return if local_digest == remote_digest

    Rails.logger.info "DockerImagePollWorker: New image digest detected (#{remote_digest}), queuing pull on all hosts"
    SiteSetting.set(DIGEST_SETTING_KEY, remote_digest)
    DockerHostImagePullWorker.perform_async
  end
end
