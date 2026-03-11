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

    run_command!("docker build --pull --build-arg TF2_VERSION=#{version} -t #{tag} #{DOCKER_DIR}")
    run_command!("docker push #{tag}")

    Rails.logger.info "CloudImageBuildWorker: Successfully built and pushed image for TF2 version #{version}"
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

  def run_command!(command)
    Rails.logger.info "CloudImageBuildWorker: Running: #{command}"
    output, status = Open3.capture2e(command)
    return if status.success?

    tail = output.to_s.lines.last(50).join
    raise "#{command.split.first(3).join(' ')} failed (exit #{status.exitstatus}):\n#{tail}"
  end
end
