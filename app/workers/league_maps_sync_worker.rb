# typed: true
# frozen_string_literal: true

class LeagueMapsSyncWorker
  include Sidekiq::Worker
  extend T::Sig

  sidekiq_options queue: :default, retry: 3

  sig { void }
  def perform
    success = LeagueMapsSyncService.fetch_and_apply

    if !success
      Rails.logger.warn("Scheduled league maps sync failed - continuing with cached data")
    end
  rescue => e
    Rails.logger.error("League maps sync worker error: #{e.class} - #{e.message}")
    raise
  end
end
