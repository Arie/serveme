# typed: true
# frozen_string_literal: true

class BuildWebsocketEchoImageWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: "low"

  LOCK_KEY = "build_websocket_echo_image"
  LOCK_TTL = 30.minutes
  DOCKER_DIR = Rails.root.join("docker", "websocket-echo").to_s
  DOCKERHUB_IMAGE = "serveme/websocket-echo"

  def perform
    return unless SITE_HOST == "serveme.tf"
    return unless acquire_lock

    tag = "#{DOCKERHUB_IMAGE}:latest"
    Rails.logger.info "BuildWebsocketEchoImageWorker: building #{tag}"
    run_command!("docker", "build", "--pull", "-t", tag, DOCKER_DIR)
    run_command!("docker", "push", tag)
    Rails.logger.info "BuildWebsocketEchoImageWorker: pushed #{tag}"
  ensure
    release_lock
  end

  private

  def acquire_lock
    Sidekiq.redis { |conn| conn.set(LOCK_KEY, "1", nx: true, ex: LOCK_TTL.to_i) }
  end

  def release_lock
    Sidekiq.redis { |conn| conn.del(LOCK_KEY) }
  end

  def run_command!(*command)
    Rails.logger.info "BuildWebsocketEchoImageWorker: Running: #{command.join(' ')}"
    output, status = T.unsafe(Open3).capture2e(*command)
    return if status.success?

    tail = output.to_s.lines.last(50).join
    raise "#{command.first(3).join(' ')} failed (exit #{status.exitstatus}):\n#{tail}"
  end
end
