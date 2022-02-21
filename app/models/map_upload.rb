# frozen_string_literal: true

require 'zip'

class MapUpload < ActiveRecord::Base
  BLACKLIST = ['pl_badwater_pro_v8.bsp', 'cp_warpath.bsp'].freeze
  belongs_to :user
  attr_accessor :maps

  validates_presence_of :user_id
  validate :validate_not_already_present,   unless: :archive?
  validate :validate_file_is_a_bsp,         unless: :archive?
  validate :validate_not_blacklisted,       unless: :archive?
  validate :validate_not_blacklisted_type,  unless: :archive?

  after_create :process_maps
  after_create :remove_uploaded_file, if: :zip?

  mount_uploader :file, MapUploader

  def process_maps
    @maps = []
    if archive?
      @maps = extract_archive
    else
      @maps << file.file.filename
    end
    bzip2_uploaded_maps unless bz2?
    upload_maps_to_servers
  end

  def self.available_maps
    Rails.cache.fetch "maps_#{last.try(:created_at).to_i}", expires_in: 1.day do
      map_filematcher = File.join(MAPS_DIR, '*.bsp')
      map_filenames = Dir.glob(map_filematcher)
      map_filenames.map { |filename| filename.match(%r{.*/(.*)\.bsp})[1] }.sort
    end
  end

  def validate_not_already_present
    return unless file.filename && self.class.map_exists?(file.filename)

    errors.add(:file, 'already available')
  end

  def validate_file_is_a_bsp
    return unless file.file && File.open(file.file.file).read(4) != 'VBSP'

    errors.add(:file, 'not a map (bsp) file')
  end

  def validate_not_blacklisted
    return unless file.filename && self.class.blacklisted?(file.filename)

    errors.add(:file, 'map blacklisted, causes server instability')
  end

  def validate_not_blacklisted_type
    return unless file.filename && self.class.blacklisted_type?(file.filename)

    errors.add(:file, 'game type not allowed')
  end

  def maps_with_full_path
    maps&.collect do |map|
      File.join(MAPS_DIR, map)
    end
  end

  def upload_maps_to_servers
    return unless maps_with_full_path&.any?

    UploadFilesToServersWorker.perform_async(files: maps_with_full_path,
                                             destination: 'maps',
                                             overwrite: false)
  end

  def self.map_exists?(filename)
    return unless File.exist?(File.join(MAPS_DIR, filename.split('/').last))

    Rails.logger.info "File #{filename} already exists in #{MAPS_DIR}"
    true
  end

  def self.blacklisted?(filename)
    return false unless filename.match(/(^.*\.bsp)/)

    target_filename = filename.match(/(^.*\.bsp)/)[1]
    BLACKLIST.include?(target_filename)
  end

  def self.blacklisted_type?(filename)
    return false unless filename.match(/(^.*\.bsp)/)

    target_filename = filename.match(/(^.*\.bsp)/) && filename.match(/(^.*\.bsp)/)[1]
    target_filename && target_filename =~ /^(trade_.*|vsh_.*|mvm_.*|jail_.*|achievement_.*)/i
  end

  def bzip2_uploaded_maps
    maps_with_full_path.each do |map_with_path|
      Rails.logger.info "Bzipping #{map_with_path}"
      `bzip2 -k #{map_with_path}`
    end
  end

  def extract_archive
    send("extract_#{archive_type}")
  end

  def extract_zip
    maps = []
    Zip::File.foreach(file.file.file) do |zipped_file|
      filename = File.basename(zipped_file.name)
      if filename.match(/^.*\.bsp$/) && !filename.match(/__MACOSX/) && !self.class.map_exists?(filename) && !self.class.blacklisted?(filename)
        Rails.logger.info "Extracting #{filename} from #{file.file.file} upload ##{id} (ZIP)"
        zipped_file.extract(File.join(MAPS_DIR, filename)) { false }
        maps << filename
      end
    end
    maps
  end

  def remove_uploaded_file
    Rails.logger.info "Removing uploaded zip #{file.file.file}"
    FileUtils.rm(file.file.file)
  end

  def extract_bz2
    filename        = file.file.filename
    source_file     = file.file.file
    target_filename = filename.match(/(^.*\.bsp)\.bz2/)[1]
    maps = []

    return if self.class.map_exists?(target_filename) || self.class.blacklisted?(target_filename) || self.class.blacklisted_type?(target_filename)

    Rails.logger.info "Extracting #{target_filename} from #{filename} upload ##{id} (BZ2)"
    data = RBzip2.default_adapter::Decompressor.new(File.new(source_file)).read

    Rails.logger.info "Writing uncompressed #{target_filename}"
    File.open(File.join(MAPS_DIR, target_filename), 'wb+') { |f| f.write(data) }
    maps << target_filename
  end

  def archive_type
    case file.to_s
    when /^.*\.zip$/
      :zip
    when /^.*\.bsp\.bz2$/
      :bz2
    end
  end

  def archive?
    archive_type.present?
  end

  def zip?
    archive_type == :zip
  end

  def bz2?
    archive_type == :bz2
  end
end
