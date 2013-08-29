class ZipFileCreator

  attr_accessor :reservation, :files_to_zip

  def initialize(reservation, files_to_zip)
    @reservation            = reservation
    @files_to_zip           = files_to_zip
  end

  def self.create(reservation, files_to_zip)
    server = reservation.server
    server.zip_file_creator_class.new(reservation, files_to_zip).create_zip
  end

  def chmod
    File.chmod(0755, zipfile_name_and_path)
  end

  def zipfile_name
    reservation.zipfile_name
  end

  def zipfile_name_and_path
    Rails.root.join("public", "uploads", zipfile_name)
  end

  def shell_escaped_files_to_zip
    files_to_zip.collect { |file| file.shellescape }
  end

  private

  def server
    reservation.server
  end

end
