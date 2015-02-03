require 'zip'

class MapUpload < ActiveRecord::Base
  belongs_to :user
  attr_accessible :file, :user_id

  validates_presence_of :user_id
  validate :validate_not_already_present,   :unless => :archive?
  validate :validate_file_is_a_bsp,         :unless => :archive?

  after_create :extract_archive,            :if => :archive?
  after_create :bzip2_uploaded_map,         :unless => :archive?
  after_create :send_to_servers

  mount_uploader :file, MapUploader

  def self.available_maps
    Rails.cache.fetch "maps_#{last.try(:created_at).to_i}", :expires_in => 1.day do
      map_filematcher = File.join(MAPS_DIR, "*.bsp")
      map_filenames = Dir.glob(map_filematcher)
      map_filenames.map { |filename| filename.match(/.*\/(.*)\.bsp/)[1] }.sort
    end
  end

  def validate_not_already_present
    if file.filename && self.class.map_exists?(file.filename)
      errors.add(:file, "already available")
    end
  end

  def validate_file_is_a_bsp
    if file.file && !archive? && File.open(file.file.file).read(4) != "VBSP"
      errors.add(:file, "not a map (bsp) file")
    end
  end

  def file_and_path
    File.join(MAPS_DIR, file.file.filename)
  end

  def send_to_servers
    UploadFilesToServersWorker.perform_async(files: [file_and_path], destination: "maps", overwrite: false)
  end

  def extract_archive
    send("extract_#{archive_type}")
  end

  def extract_zip
    Zip::File.foreach(file.file.file) do |zipped_file|
      file_and_path = zipped_file.name
      filename = file_and_path.split("/").last
      if file_and_path.match(/^.*\.bsp$/) && !file_and_path.match(/__MACOSX/) && !self.class.map_exists?(filename)
        Rails.logger.info "Extracting #{filename} from #{file_and_path} upload ##{self.id} (ZIP)"
        zipped_file.extract(File.join(MAPS_DIR, filename)) { false }
        self.class.bzip2_uploaded_file(filename)
      end
    end
    FileUtils.rm(file.file.file)
  end

  def extract_bz2
    filename        = file.file.filename
    source_file     = file.file.file
    target_filename = filename.match(/(^.*\.bsp)\.bz2/)[1]

    if !self.class.map_exists?(target_filename)
      Rails.logger.info "Extracting #{target_filename} from #{file_and_path} upload ##{self.id} (BZ2)"
      data  = RBzip2.default_adapter::Decompressor.new(File.new(source_file)).read

      Rails.logger.info "Writing uncompressed #{target_filename}"
      File.open(File.join(MAPS_DIR, target_filename), "wb+") { |f| f.write(data) }
    end
  end

  def archive_type
    case file.to_s
    when /^.*\.zip$/
      :zip
    when /^.*\.bsp\.bz2$/
      :bz2
    else
      nil
    end
  end

  def archive?
    archive_type.present?
  end

  def bzip2_uploaded_map
    target_file   = File.new("#{file_and_path}.bz2", "wb+")
    bz2           = RBzip2.default_adapter::Compressor.new(target_file)
    bz2.write(file.read)
    bz2.close
  end

  def self.map_exists?(filename)
    if File.exists?(File.join(MAPS_DIR, filename.split("/").last))
      Rails.logger.info "File #{filename} already exists in #{MAPS_DIR}"
      true
    end
  end

  def self.bzip2_uploaded_file(filename)
    Rails.logger.info "Bzipping #{filename}"
    file          = File.open(File.join(MAPS_DIR, filename))
    target_file   = File.new("#{File.join(MAPS_DIR, filename)}.bz2", "wb+")
    bz2           = RBzip2.default_adapter::Compressor.new(target_file)
    bz2.write(file.read)
    bz2.close
  end

end
