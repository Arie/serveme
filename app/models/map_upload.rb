# typed: false
# frozen_string_literal: true

require "zip"

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
    Rails.cache.fetch("map_bucket_objects", expires_in: 10.minutes) do
      fetch_bucket_objects
    end
  end

  def self.refresh_bucket_objects
    Rails.cache.delete("map-list-view-for-admin-false")
    Rails.cache.delete("map-list-view-for-admin-true")
    Rails.cache.write("map_bucket_objects", fetch_bucket_objects, expire_in: 11.minutes)
  end

  def self.fetch_bucket_objects
    return [] unless ActiveStorage::Blob.service.respond_to?(:bucket)

    ActiveStorage::Blob.service.bucket.objects(prefix: "maps/").to_a.filter { |o| o.key.ends_with?(".bsp") }.map { |o| { key: o.key, map_name: o.key.match(%r{.*/(.*)\.bsp})[1], size: o.size } }.sort_by { |h| h[:map_name].downcase }
  end

  def self.map_statistics
    Rails.cache.fetch("map_statistics", expires_in: 10.minutes) do
      fetch_map_statistics
    end
  end

  def self.refresh_map_statistics
    Rails.cache.write("map_statistics", fetch_map_statistics, expire_in: 11.minutes)
  end

  def self.fetch_map_statistics
    Reservation.where.not(first_map: [ nil, "" ]).group(:first_map).select(
      "count(first_map) AS times_played",
      "MAX(starts_at) AS last_played",
      "MIN(starts_at) AS first_played",
      "first_map"
    ).inject({}) do |m, r|
      m.merge!({ r.first_map => { times_played: r.times_played, last_played: r.last_played, first_played: r.first_played } })
    end
  end

  def self.delete_bucket_object(map_name)
    ActiveStorage::Blob.service.delete("maps/#{map_name}.bsp")
    ActiveStorage::Blob.service.delete("maps/#{map_name}.bsp.bz2")
    Rails.cache.write("map_bucket_objects", bucket_objects.reject { |o| o[:map_name] == map_name }, expires_in: 11.minutes)
    Rails.cache.write("map_statistics", map_statistics.reject { |s| s[0] == map_name }, expires_in: 11.minutes)
    Turbo::StreamsChannel.broadcast_replace_to("admin-maps-list", partial: "map_uploads/admin_list", locals: { bucket_objects: bucket_objects, map_statistics: map_statistics })
  end

  def self.invalid_types_regex
    /(achievement_|jail_|mvm_|vsh_|zi_)/i
  end

  def validate_file_is_a_bsp
    # Skip validation if this is an existing blob with maps/ prefix and no new attachment
    return if file&.blob&.key&.start_with?("maps/") && !attachment_changes["file"]

    return unless attachment_changes["file"]

    attachable = attachment_changes["file"].attachable

    return if attachable.is_a?(ActiveStorage::Blob)

    return unless attachable.read(4) != "VBSP"

    errors.add(:file, "not a map (bsp) file")
  end

  def validate_not_blacklisted_type
    return unless file&.blob&.filename && self.class.blacklisted_type?(file.blob.filename.to_s)

    errors.add(:file, "game type not allowed")
  end

  def validate_not_already_present
    return unless file&.blob&.key

    is_r2_upload = file.blob.persisted? && file.blob.key.start_with?("maps/")

    return if is_r2_upload

    errors.add(:file, "already available") if ActiveStorage::Blob.service.exist?(file.blob.key)
  end

  def self.blacklisted_type?(filename)
    target_filename = filename.match(/(^.*\.bsp)/) && filename.match(/(^.*\.bsp)/)[1]
    target_filename&.starts_with?(invalid_types_regex)
  end

  def self.create_from_direct_upload(user:, key:, filename:)
    existing_blob = ActiveStorage::Blob.find_by(key: key)
    return { success: false, error: "File already exists in database" } if existing_blob

    validation_result = validate_direct_upload_file(key)
    unless validation_result[:valid]
      begin
        ActiveStorage::Blob.service.delete(key)
      rescue => e
        Rails.logger.error "Failed to delete invalid file #{key}: #{e.message}"
      end
      return { success: false, error: validation_result[:error] }
    end

    begin
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename: filename,
        byte_size: validation_result[:size],
        checksum: validation_result[:checksum],
        content_type: "application/octet-stream",
        service_name: "cloudflare"
      )

      blob.update!(key: key)

      map_upload = new(user: user)
      map_upload.file.attach(blob)

      if map_upload.save
        { success: true, map_upload: map_upload }
      else
        { success: false, error: map_upload.errors.full_messages.join(", ") }
      end
    rescue => e
      Rails.logger.error "Error completing upload: #{e.message}"
      { success: false, error: "Failed to complete upload" }
    end
  end

  def self.validate_direct_upload_file(key)
    begin
      s3_resource = ActiveStorage::Blob.service.client
      s3_client = s3_resource.client
      bucket_name = Rails.application.credentials.dig(:cloudflare, :bucket)

      head_response = s3_client.head_object(bucket: bucket_name, key: key)
      file_size = head_response.content_length

      range_response = s3_client.get_object(bucket: bucket_name, key: key, range: "bytes=0-3")
      header = range_response.body.read

      unless header == "VBSP"
        return { valid: false, error: "Not a valid BSP file" }
      end

      full_response = s3_client.get_object(bucket: bucket_name, key: key)
      checksum = Digest::MD5.base64digest(full_response.body.read)

      { valid: true, size: file_size, checksum: checksum }
    rescue Aws::S3::Errors::NoSuchKey
      { valid: false, error: "File not found" }
    rescue => e
      Rails.logger.error "Error validating file #{key}: #{e.message}"
      { valid: false, error: "Failed to validate file" }
    end
  end

  private

  def set_s3_prefix
    return unless file.attached? && file.blob.present?
    return if file.blob.key.start_with?("maps/")

    file.blob.key = "maps/#{file.blob.filename}"
  end
end
