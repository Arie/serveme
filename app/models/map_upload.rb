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
    bucket_objects.map { |h| h[:map_name] }
  end

  def refresh_available_maps
    AvailableMapsWorker.perform_async
  end

  def self.bucket_objects
    Rails.cache.fetch('map_bucket_objects', expires_in: 10.minutes) do
      fetch_bucket_objects
    end
  end

  def self.refresh_bucket_objects
    Rails.cache.write('map_bucket_objects', fetch_bucket_objects, expire_in: 11.minutes)
  end

  def self.fetch_bucket_objects
    return [] unless ActiveStorage::Blob.service.respond_to?(:bucket)

    ActiveStorage::Blob.service.bucket.objects(prefix: 'maps/').to_a.filter { |o| o.key.ends_with?('.bsp') }.map { |o| { key: o.key, map_name: o.key.match(%r{.*/(.*)\.bsp})[1], size: o.size } }.sort_by { |h| h[:map_name].downcase }
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
