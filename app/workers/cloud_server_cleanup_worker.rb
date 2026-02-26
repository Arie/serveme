# typed: true
# frozen_string_literal: true

class CloudServerCleanupWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: "default"

  MAX_AGE = 6.hours

  def perform
    CloudServer.where(cloud_status: %w[provisioning ssh_ready ready])
               .where(cloud_created_at: ...MAX_AGE.ago)
               .find_each do |server|
      Rails.logger.info "CloudServerCleanupWorker: Destroying stranded cloud server #{server.id} (created #{server.cloud_created_at})"
      CloudServerDestroyWorker.perform_async(server.id)
    end
  end
end
