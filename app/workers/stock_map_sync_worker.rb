# typed: true
# frozen_string_literal: true

class StockMapSyncWorker
  include Sidekiq::Worker
  extend T::Sig

  sidekiq_options retry: 3, queue: "low"

  LOCK_TTL = 3.hours

  sig { params(version: T.untyped).void }
  def perform(version = nil)
    return unless SITE_HOST == "serveme.tf"

    if version && !acquire_lock(version)
      Rails.logger.info "Stock map sync for TF2 #{version} already ran, skipping"
      return
    end

    completed = T.let(false, T::Boolean)
    begin
      result = StockMapSync.new.call
      Rails.logger.info "Stock map sync finished: #{result}"

      raise "Stock map sync could not sync: #{result[:failed].join('; ')}" if result[:failed].any?

      completed = true
    ensure
      release_lock(version) if version && !completed
    end
  end

  private

  sig { params(version: T.untyped).returns(T.untyped) }
  def acquire_lock(version)
    Sidekiq.redis { |conn| conn.set(lock_key(version), Time.current.to_i, nx: true, ex: LOCK_TTL.to_i) }
  end

  sig { params(version: T.untyped).void }
  def release_lock(version)
    Sidekiq.redis { |conn| conn.del(lock_key(version)) }
  end

  sig { params(version: T.untyped).returns(String) }
  def lock_key(version)
    "stock_map_sync:#{version}"
  end
end
