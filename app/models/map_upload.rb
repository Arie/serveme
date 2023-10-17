# frozen_string_literal: true

require 'zip'

class MapUpload < ActiveRecord::Base
  belongs_to :user
  has_one_attached :file
  attr_accessor :maps

  validates_presence_of :user_id
  validate :validate_not_already_present
  validate :validate_file_is_a_bsp
  validate :validate_not_blacklisted_type

  before_validation :set_s3_prefix
  after_save :refresh_available_maps

  def self.available_maps
    Rails.cache.fetch 'available_maps', expires_in: 10.minutes do
      fetch_available_maps
    end
  end

  def self.refresh_available_maps
    Rails.cache.write 'available_maps', expires_in: 10.minutes do
      fetch_available_maps
    end
  end

  def refresh_available_maps
    AvailableMapsWorker.perform_async
  end

  def self.fetch_available_maps
    if ActiveStorage::Blob.service.respond_to?(:bucket)
      ActiveStorage::Blob.service.bucket.objects(prefix: 'maps/').collect(&:key).filter { |f| f.ends_with?('.bsp') }.map { |filename| filename.match(%r{.*/(.*)\.bsp})[1] }.sort
    else
      []
    end
  end

  def validate_file_is_a_bsp
    return unless attachment_changes['file'] && attachment_changes['file'].attachable.read(4) != 'VBSP'

    errors.add(:file, 'not a map (bsp) file')
  end

  def validate_not_blacklisted_type
    return unless file&.blob&.filename && self.class.blacklisted_type?(file.blob.filename.to_s)

    errors.add(:file, 'game type not allowed')
  end

  def validate_not_already_present
    return unless file&.blob&.key

    errors.add(:file, 'already available') if ActiveStorage::Blob.service.exist?(file.blob.key)
  end

  def self.blacklisted?(filename)
    target_filename = filename.match(/(^.*\.bsp)/)[1]
    BLACKLIST.include?(target_filename)
  end

  def self.blacklisted_type?(filename)
    target_filename = filename.match(/(^.*\.bsp)/) && filename.match(/(^.*\.bsp)/)[1]
    target_filename && target_filename =~ /^(trade_.*|mvm_.*|jail_.*|achievement_.*)/i
  end

  private

  def set_s3_prefix
    file.blob.key = "maps/#{file.blob.filename}"
  end
end
