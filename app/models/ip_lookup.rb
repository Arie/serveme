# typed: true
# frozen_string_literal: true

class IpLookup < ActiveRecord::Base
  attr_accessor :synced_from_region

  validates :ip, presence: true, uniqueness: true

  after_create_commit :schedule_cross_region_sync
  after_update_commit :schedule_cross_region_sync_on_false_positive_change
  after_update_commit :schedule_cross_region_sync_on_ban_change

  scope :residential_proxies, -> { where(is_residential_proxy: true) }

  def self.cached?(ip)
    exists?(ip: ip)
  end

  def self.find_cached(ip)
    find_by(ip: ip)
  end

  def self.upsert_from_sync(attributes)
    attrs = attributes.to_h.symbolize_keys.slice(
      :ip, :is_proxy, :is_residential_proxy, :fraud_score,
      :connection_type, :isp, :country_code, :raw_response, :false_positive,
      :is_banned, :ban_reason
    )

    existing = find_by(ip: attrs[:ip])
    if existing
      existing.update!(attrs.except(:ip))
      existing
    else
      record = new(attrs)
      record.synced_from_region = true
      record.save!
      record
    end
  end

  private

  def schedule_cross_region_sync
    return if synced_from_region

    IpLookupSyncWorker.perform_async(id)
  end

  def schedule_cross_region_sync_on_false_positive_change
    return unless saved_change_to_false_positive?

    IpLookupSyncWorker.perform_async(id)
  end

  def schedule_cross_region_sync_on_ban_change
    return unless saved_change_to_is_banned?

    IpLookupSyncWorker.perform_async(id)
  end
end
