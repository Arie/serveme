# typed: true
# frozen_string_literal: true

class CloudImageBuildWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "low"

  LOCK_KEY = "cloud_image_build"
  LOCK_TTL = 2.hours
  DOCKER_DIR = Rails.root.join("docker", "tf2-cloud-server").to_s
  DOCKERHUB_IMAGE = "serveme/tf2-cloud-server"

  def perform(cloud_image_build_id)
    @build = CloudImageBuild.find(cloud_image_build_id)
    return if @build.finished?
    return unless SITE_HOST == "serveme.tf"

    @streamer = CloudImageBuildOutputStreamer.new(@build)
    @lock_held = false

    begin
      @build.update!(status: "running", started_at: Time.current)
      broadcast_status

      return mark_skipped_locked unless acquire_lock(@build.version)
      @lock_held = true

      run_phase("building") { run_streamed!(*build_command) }
      run_phase("pushing")  { run_streamed!("docker", "push", tag) }

      run_phase("notifying") do
        digest = pushed_digest
        if digest
          SiteSetting.set(DockerImagePollWorker::DIGEST_SETTING_KEY, digest)
          Rails.cache.delete("cloud_image_registry_digest")
        end
        @streamer.append("Notifying other regions...\n")
        notify_other_regions(digest)
        @build.update!(digest: digest) if digest
      end

      run_phase("triggering_pulls") do
        @streamer.append("Queuing pull on all hosts...\n")
        DockerHostImagePullWorker.perform_async
      end

      @streamer.flush!
      @build.update!(status: "succeeded", current_phase: nil, finished_at: Time.current)
      broadcast_status
    rescue StandardError => e
      @streamer.append("\n[ERROR] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}\n")
      @streamer.flush!
      @build.update!(status: "failed", current_phase: nil, finished_at: Time.current)
      broadcast_status
    ensure
      release_lock if @lock_held
    end
  end

  private

  def tag
    "#{DOCKERHUB_IMAGE}:latest"
  end

  def build_command
    args = [ "docker", "build" ]
    args << "--pull" if @build.force_pull
    args.push("--build-arg", "TF2_VERSION=#{@build.version}", "-t", tag, DOCKER_DIR)
    args
  end

  def run_phase(phase)
    @build.update!(current_phase: phase)
    broadcast_status
    yield
    @streamer.flush!
  end

  def run_streamed!(*command)
    @streamer.append("$ #{command.join(' ')}\n")
    T.unsafe(Open3).popen2e(*command) do |_stdin, stdout_and_stderr, wait_thread|
      stdout_and_stderr.each_line { |line| @streamer.append(line) }
      status = wait_thread.value
      raise "#{command.first(2).join(' ')} failed (exit #{status.exitstatus})" unless status.success?
    end
  end

  def mark_skipped_locked
    @build.update!(status: "skipped_locked", finished_at: Time.current,
                   output: "[skipped] Another build was already running")
    broadcast_status
  end

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

      begin
        conn = Faraday.new(url: base_url) do |f|
          f.request :json
          f.options.timeout = 10
          f.options.open_timeout = 5
        end
        conn.post("/api/docker_image_updates") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.body = { digest: digest }.compact.to_json
        end
        @streamer.append("  -> notified #{region_key}\n")
      rescue Faraday::Error => e
        @streamer.append("  -> WARN: #{region_key} notify failed: #{e.message}\n")
      end
    end
  end

  def broadcast_status
    Turbo::StreamsChannel.broadcast_replace_to(
      @build,
      target: "build-header-#{@build.id}",
      partial: "admin/cloud_image_builds/header",
      locals: { build: @build }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "cloud_image_builds_index",
      target: "trigger-card",
      partial: "admin/cloud_image_builds/trigger_card",
      locals: { in_progress: CloudImageBuild.in_progress.first }
    )
    CloudImageBuild.broadcast_history
  end
end
