# typed: true
# frozen_string_literal: true

require "shellwords"

class CloudSnapshotWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "low"

  LOCK_KEY = "cloud_snapshot"
  LOCK_TTL = 30.minutes

  def perform(provider_name = "hetzner", location = "fsn1")
    return unless acquire_lock

    provider = CloudProvider.for(provider_name)

    Rails.logger.info "CloudSnapshotWorker: Creating snapshot for #{provider_name} in #{location}"

    setup_script = <<~BASH
      #!/bin/bash
      docker pull serveme/tf2-cloud-server:latest
      touch /tmp/image-ready
    BASH

    # 1. Create temp VM
    server_id, ip = provider.create_snapshot_server(location, setup_script)
    Rails.logger.info "CloudSnapshotWorker: VM running at #{ip}"

    # 2. Wait for Docker image pull
    ssh_key_file = CloudServer.new.send(:cloud_ssh_key_file)
    image_ready = T.let(false, T::Boolean)
    180.times do
      result = `ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i #{ssh_key_file.shellescape} root@#{ip.shellescape} 'test -f /tmp/image-ready && echo READY' 2>/dev/null`.strip
      if result == "READY"
        image_ready = true
        break
      end
      sleep 5
    end

    unless image_ready
      Rails.logger.error "CloudSnapshotWorker: Docker image pull did not complete in time"
      provider.destroy_server(server_id)
      return
    end

    Rails.logger.info "CloudSnapshotWorker: Docker image pulled, creating snapshot"

    # 3. Halt, snapshot, wait
    provider.halt_server(server_id)

    description = "serveme-cloud-#{Time.current.strftime('%Y%m%d-%H%M')}"
    snapshot_id = provider.create_snapshot(server_id, description)
    Rails.logger.info "CloudSnapshotWorker: Snapshot #{snapshot_id} created, waiting for availability"

    provider.wait_for_snapshot(snapshot_id)

    # 4. Destroy temp VM
    provider.destroy_server(server_id)

    # 5. Delete old snapshots (keep only the new one)
    deleted = provider.delete_old_snapshots(snapshot_id)
    Rails.logger.info "CloudSnapshotWorker: Deleted #{deleted} old snapshot(s)" if deleted > 0

    Rails.logger.info "CloudSnapshotWorker: Snapshot #{snapshot_id} ready. Update credentials: #{provider.snapshot_credential_key}: #{snapshot_id}"
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
end
