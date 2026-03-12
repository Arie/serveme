# typed: true
# frozen_string_literal: true

class DockerImagePollWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "default"

  DOCKERHUB_IMAGE = "serveme/tf2-cloud-server"
  DIGEST_SETTING_KEY = "docker_image_digest"

  def perform
    return if DockerHost.active.none?

    remote_digest = fetch_remote_digest
    return unless remote_digest

    local_digest = SiteSetting.get(DIGEST_SETTING_KEY)
    if local_digest != remote_digest
      Rails.logger.info "DockerImagePollWorker: New image digest detected (#{remote_digest}), queuing pull on all hosts"
      SiteSetting.set(DIGEST_SETTING_KEY, remote_digest)
      DockerHostImagePullWorker.perform_async
    end
  end

  private

  def fetch_remote_digest
    auth_conn = Faraday.new(url: "https://auth.docker.io") do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
    end
    token_response = auth_conn.get("/token?service=registry.docker.io&scope=repository:#{DOCKERHUB_IMAGE}:pull")
    return nil unless token_response.success?

    token = JSON.parse(token_response.body)["token"]

    registry_conn = Faraday.new(url: "https://registry-1.docker.io") do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
    end
    manifest_response = registry_conn.head("/v2/#{DOCKERHUB_IMAGE}/manifests/latest") do |req|
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Accept"] = "application/vnd.docker.distribution.manifest.v2+json"
    end

    manifest_response.headers["docker-content-digest"]
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn "DockerImagePollWorker: Failed to check registry: #{e.message}"
    nil
  end
end
