# typed: true
# frozen_string_literal: true

class IpLookup < ActiveRecord::Base
  attr_accessor :synced_from_region

  validates :ip, presence: true, uniqueness: true

  after_create_commit :schedule_cross_region_sync

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
      :connection_type, :isp, :country_code, :raw_response
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
end
