# typed: true
# frozen_string_literal: true

require "zip"

class MapUpload < ActiveRecord::Base
  extend T::Sig

  belongs_to :user
  has_one_attached :file
  attr_accessor :maps

  validates_presence_of :user_id
  validate :validate_not_already_present
  validate :validate_file_is_a_bsp
  validate :validate_not_blacklisted_type

  before_validation :set_s3_prefix
  after_save :refresh_available_maps

  sig { returns(T::Array[T.untyped]) }
  def self.available_maps
    bucket_objects.map { |h| h[:map_name] }
  end

  sig { void }
  def refresh_available_maps
    AvailableMapsWorker.perform_async
  end

  sig { returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def self.bucket_objects
    Rails.cache.fetch("map_bucket_objects", expires_in: 10.minutes) do
      fetch_bucket_objects
    end
  end

  sig { void }
  def self.refresh_bucket_objects
    Rails.cache.delete("map-list-view-for-admin-false")
    Rails.cache.delete("map-list-view-for-admin-true")
    Rails.cache.write("map_bucket_objects", fetch_bucket_objects, expire_in: 11.minutes)
  end

  sig { returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def self.fetch_bucket_objects
    return [] unless ActiveStorage::Blob.service.respond_to?(:bucket)

    # Fetch all map uploads with their users in a single query
    # This avoids N+1 queries by eager loading all associations
    uploaders_by_name = {}

    # Get CarrierWave uploads (filename in file column)
    carrierwave_uploads = MapUpload.includes(:user)
                                  .where.not(file: [ nil, "" ])
                                  .where("file LIKE '%.bsp'")

    carrierwave_uploads.each do |upload|
      # Extract map name from CarrierWave file column without calling filename()
      file_name = upload[:file]
      next unless file_name&.end_with?(".bsp")

      map_name = file_name.gsub(/\.bsp$/, "")
      uploaders_by_name[map_name] = upload
    end

    # Get ActiveStorage uploads with preloaded blob data
    activestorage_uploads = MapUpload.includes(:user, file_attachment: :blob)
                                    .joins(:file_attachment)
                                    .joins("JOIN active_storage_blobs ON active_storage_attachments.blob_id = active_storage_blobs.id")
                                    .where("active_storage_blobs.key LIKE 'maps/%'")

    activestorage_uploads.each do |upload|
      # Extract map name from ActiveStorage key without calling filename()
      blob_key = upload.file_attachment&.blob&.key
      next unless blob_key&.start_with?("maps/")

      map_name = blob_key.match(%r{maps/(.*)\.bsp})[1]
      next unless map_name

      # Prioritize ActiveStorage uploads over CarrierWave ones for the same map name
      uploaders_by_name[map_name] = upload
    end

    ActiveStorage::Blob.service.bucket.objects(prefix: "maps/").to_a.filter { |o| o.key.ends_with?(".bsp") }.map do |o|
      map_name = o.key.match(%r{.*/(.*)\.bsp})[1]
      uploader_info = uploaders_by_name[map_name]
      uploader = uploader_info&.user

      {
        key: o.key,
        map_name: map_name,
        size: o.size,
        uploader: uploader,
        upload_date: uploader_info&.created_at
      }
    end.sort_by { |h| h[:map_name].downcase }
  end

  sig { returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
  def self.map_statistics
    Rails.cache.fetch("map_statistics", expires_in: 10.minutes) do
      fetch_map_statistics
    end
  end

  sig { void }
  def self.refresh_map_statistics
    Rails.cache.write("map_statistics", fetch_map_statistics, expire_in: 11.minutes)
  end

  sig { returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
  def self.fetch_map_statistics
    Reservation.where.not(first_map: [ nil, "" ]).group(:first_map).select(
      "count(first_map) AS times_played",
      "MAX(starts_at) AS last_played",
      "MIN(starts_at) AS first_played",
      "first_map"
    ).inject({}) do |m, r|
      # Use T.unsafe to access dynamic attributes from the SQL query
      m.merge!({ T.unsafe(r).first_map => { times_played: T.unsafe(r).times_played, last_played: T.unsafe(r).last_played, first_played: T.unsafe(r).first_played } })
    end
  end

  sig { params(map_name: String).void }
  def self.delete_bucket_object(map_name)
    ActiveStorage::Blob.service.delete("maps/#{map_name}.bsp")
    ActiveStorage::Blob.service.delete("maps/#{map_name}.bsp.bz2")
    Rails.cache.write("map_bucket_objects", bucket_objects.reject { |o| o[:map_name] == map_name }, expires_in: 11.minutes)
    Rails.cache.write("map_statistics", map_statistics.reject { |s| s[0] == map_name }, expires_in: 11.minutes)
    Turbo::StreamsChannel.broadcast_replace_to("admin-maps-list", partial: "map_uploads/admin_list", locals: { bucket_objects: bucket_objects, map_statistics: map_statistics })
  end

  sig { returns(Regexp) }
  def self.invalid_types_regex
    /(achievement_|jail_|mvm_|vsh_|zi_)/i
  end

  sig { void }
  def validate_file_is_a_bsp
    # Skip validation if this is an existing blob with maps/ prefix and no new attachment
    return if file.attached? && T.unsafe(file).blob&.key&.start_with?("maps/") && !attachment_changes["file"]

    return unless attachment_changes["file"]

    attachable = attachment_changes["file"].attachable

    return if attachable.is_a?(ActiveStorage::Blob)

    return unless attachable.read(4) != "VBSP"

    errors.add(:file, "not a map (bsp) file")
  end

  sig { void }
  def validate_not_blacklisted_type
    return unless file.attached? && T.unsafe(file).blob&.filename && self.class.blacklisted_type?(T.unsafe(file).blob.filename.to_s)

    errors.add(:file, "game type not allowed")
  end

  sig { void }
  def validate_not_already_present
    return unless file.attached? && T.unsafe(file).blob&.key

    blob = T.unsafe(file).blob
    is_r2_upload = blob.persisted? && blob.key.start_with?("maps/")

    return if is_r2_upload

    errors.add(:file, "already available") if ActiveStorage::Blob.service.exist?(blob.key)
  end

  sig { params(filename: String).returns(T.nilable(T::Boolean)) }
  def self.blacklisted_type?(filename)
    match = filename.match(/(^.*\.bsp)/)
    return nil unless match

    target_filename = match[1]
    target_filename&.starts_with?(invalid_types_regex)
  end

  sig { params(user: User, key: String, filename: String).returns(T::Hash[Symbol, T.untyped]) }
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

  sig { params(key: String).returns(T::Hash[Symbol, T.untyped]) }
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

  sig { returns(T.nilable(String)) }
  def filename
    if file.attached? && T.unsafe(file).blob
      # ActiveStorage upload
      T.unsafe(file).blob.filename.to_s
    elsif self[:file].present?
      # CarrierWave upload (filename stored in file column)
      self[:file]
    elsif name.present?
      # Fallback to name field
      name
    else
      nil
    end
  end

  sig { returns(T.nilable(String)) }
  def map_name
    fname = filename
    return nil unless fname

    # Remove .bsp extension if present
    fname.gsub(/\.bsp$/, "")
  end

  sig { params(file_size_lookup: T.nilable(T::Hash[Integer, Integer])).returns(T.nilable(Integer)) }
  def file_size(file_size_lookup = nil)
    if file.attached? && T.unsafe(file).blob
      # ActiveStorage upload - size is stored in blob
      T.unsafe(file).blob.byte_size
    elsif self[:file].present?
      # CarrierWave upload - use preloaded size if available, otherwise check bucket
      if file_size_lookup && file_size_lookup.key?(id)
        file_size_lookup[id]
      else
        bucket_key = "maps/#{self[:file]}"
        bucket_objects = self.class.bucket_objects
        bucket_object = bucket_objects.find { |obj| obj[:key] == bucket_key }
        bucket_object&.[](:size)
      end
    else
      nil
    end
  end

  sig { params(file_size_lookup: T.nilable(T::Hash[Integer, Integer])).returns(String) }
  def formatted_file_size(file_size_lookup = nil)
    size = file_size(file_size_lookup)
    return "Unknown" unless size

    "#{(size / 1024.0 / 1024.0).round(1)} MB"
  end

  sig { params(file_exists_lookup: T.nilable(T::Hash[Integer, T::Boolean])).returns(T::Boolean) }
  def file_exists?(file_exists_lookup = nil)
    if file.attached?
      # ActiveStorage upload - check if blob exists
      T.unsafe(file).blob.present?
    elsif self[:file].present?
      # CarrierWave upload - use preloaded existence if available
      if file_exists_lookup && file_exists_lookup.key?(id)
        file_exists_lookup[id]
      else
        # Fallback: check bucket objects
        bucket_key = "maps/#{self[:file]}"
        bucket_objects = self.class.bucket_objects
        bucket_objects.any? { |obj| obj[:key] == bucket_key }
      end
    else
      false
    end
  end

  private

  sig { void }
  def set_s3_prefix
    return unless file.attached? && T.unsafe(file).blob&.present?

    blob = T.unsafe(file).blob
    return if blob.key.start_with?("maps/")

    blob.key = "maps/#{blob.filename}"
  end
end
