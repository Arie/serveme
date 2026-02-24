# typed: true
# frozen_string_literal: true

class CloudImageBuildWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "low"

  LOCK_KEY = "cloud_image_build"
  LOCK_TTL = 30.minutes
  DOCKER_DIR = Rails.root.join("docker", "tf2-cloud-server").to_s
  IMAGE = "ghcr.io/arie/tf2-cloud-server"

  def perform(version)
    return unless SITE_HOST == "serveme.tf"
    return unless acquire_lock(version)

    ghcr_token = Rails.application.credentials.dig(:cloud_servers, :ghcr_token)
    return unless ghcr_token

    Rails.logger.info "CloudImageBuildWorker: Building new image for TF2 version #{version}"

    unless run_command("echo #{ghcr_token} | docker login ghcr.io -u fakkelbrigade --password-stdin")
      Rails.logger.error "CloudImageBuildWorker: Failed to login to GHCR"
      return
    end

    tag = "#{IMAGE}:latest"

    unless run_command("docker build --pull -t #{tag} #{DOCKER_DIR}")
      Rails.logger.error "CloudImageBuildWorker: Docker build failed"
      return
    end

    unless run_command("docker push #{tag}")
      Rails.logger.error "CloudImageBuildWorker: Docker push failed"
      return
    end

    Rails.logger.info "CloudImageBuildWorker: Successfully built and pushed #{tag} for TF2 version #{version}"
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

  def run_command(command)
    Rails.logger.info "CloudImageBuildWorker: Running: #{command.gsub(/echo .+ \|/, 'echo [REDACTED] |')}"
    system(command)
  end
end
