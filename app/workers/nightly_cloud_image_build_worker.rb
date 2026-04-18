# typed: true
# frozen_string_literal: true

class NightlyCloudImageBuildWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "low"

  def perform
    version = Rails.cache.read("latest_server_version")
    return unless version

    CloudImageBuildWorker.perform_async(version, true)
  end
end
