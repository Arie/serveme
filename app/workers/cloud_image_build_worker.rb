# typed: true
# frozen_string_literal: true

class CloudImageBuildWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: "low"

  LOCK_KEY = "cloud_image_build"
  LOCK_TTL = 30.minutes
  DOCKER_DIR = Rails.root.join("docker", "tf2-cloud-server").to_s
  DOCKERHUB_IMAGE = "serveme/tf2-cloud-server"

  def perform(version)
    return unless SITE_HOST == "serveme.tf"
    return unless acquire_lock(version)

    Rails.logger.info "CloudImageBuildWorker: Building new image for TF2 version #{version}"

    tag = "#{DOCKERHUB_IMAGE}:latest"

    run_command!("docker", "build", "--pull", "--build-arg", "TF2_VERSION=#{version}", "-t", tag, DOCKER_DIR)
    run_command!("docker", "push", tag)

    digest = pushed_digest
    Rails.logger.info "CloudImageBuildWorker: Successfully built and pushed image for TF2 version #{version} (digest: #{digest})"
    SiteSetting.set(DockerImagePollWorker::DIGEST_SETTING_KEY, digest) if digest
    DockerHostImagePullWorker.perform_async
    notify_other_regions(digest)
  ensure
    release_lock
  end

  private

  def acquire_lock(version)
    Sidekiq.redis { |conn| conn.set(LOCK_KEY, version, nx: true, ex: LOCK_TTL.to_i) }
  end

  def release_lock
    Sidekiq.redis { |conn| conn.del(LOCK_KEY) }
  end

  def pushed_digest
    output, = Open3.capture2e("docker", "inspect", "--format={{index .RepoDigests 0}}", "#{DOCKERHUB_IMAGE}:latest")
    digest = output.strip.split("@").last
    digest if digest.present? && digest.start_with?("sha256:")
  rescue StandardError => e
    Rails.logger.warn "CloudImageBuildWorker: Failed to get pushed digest: #{e.message}"
    nil
  end

  def notify_other_regions(digest)
    current_region = case SITE_HOST
    when "serveme.tf" then :eu
    when "na.serveme.tf" then :na
    when "sea.serveme.tf" then :sea
    when "au.serveme.tf" then :au
    end

    IpLookupSyncWorker::REGIONS.each do |region_key, base_url|
      next if region_key == current_region

      api_key = Rails.application.credentials.dig(:serveme, region_key)
      next unless api_key

      conn = Faraday.new(url: base_url) do |f|
        f.request :json
        f.options.timeout = 10
        f.options.open_timeout = 5
      end

      conn.post("/api/docker_image_updates") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.body = { digest: digest }.compact.to_json
      end

      Rails.logger.info "CloudImageBuildWorker: Notified #{region_key} to pull new image"
    rescue Faraday::Error => e
      Rails.logger.warn "CloudImageBuildWorker: Failed to notify #{region_key}: #{e.message}"
    end
  end

  def run_command!(*command)
    Rails.logger.info "CloudImageBuildWorker: Running: #{command.join(' ')}"
    output, status = T.unsafe(Open3).capture2e(*command)
    return if status.success?

    tail = output.to_s.lines.last(50).join
    raise "#{command.first(3).join(' ')} failed (exit #{status.exitstatus}):\n#{tail}"
  end
end
