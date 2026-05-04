# typed: true
# frozen_string_literal: true

class NightlyCloudImageBuildWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "low"

  def perform
    version = Rails.cache.read("latest_server_version")
    return unless version

    build = CloudImageBuild.create!(version: version.to_s, force_pull: true, status: "queued")
    CloudImageBuildWorker.perform_async(build.id)
    CloudImageBuild.broadcast_history
  end
end
