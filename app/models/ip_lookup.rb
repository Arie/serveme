# typed: true
# frozen_string_literal: true

class IpLookup < ActiveRecord::Base
  validates :ip, presence: true, uniqueness: true

  scope :residential_proxies, -> { where(is_residential_proxy: true) }

  def self.cached?(ip)
    exists?(ip: ip)
  end

  def self.find_cached(ip)
    find_by(ip: ip)
  end
end
