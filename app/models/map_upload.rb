class MapUpload < ActiveRecord::Base
  belongs_to :user
  attr_accessible :file, :user_id

  validates_presence_of :user_id
  validate :validate_not_already_present
  validate :validate_file_is_a_bsp

  after_create :bzip2_uploaded_file
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
    if file.filename && File.exists?(File.join(MAPS_DIR, file.filename))
      errors.add(:file, "already available")
    end
  end

  def validate_file_is_a_bsp
    unless file.file && File.open(file.file.file).read(4) == "VBSP"
      errors.add(:file, "not a map (bsp) file")
    end
  end

  def file_and_path
    File.join(MAPS_DIR, file.filename)
  end

  def bzip2_uploaded_file
    target_file   = File.new("#{file_and_path}.bz2", "wb+")
    bz2           = RBzip2.default_adapter::Compressor.new(target_file)
    bz2.write(file.read)
    bz2.close
  end

  def send_to_servers
    UploadFilesToServersWorker.perform_async(files: [file_and_path], destination: "maps", overwrite: false)
  end

end
