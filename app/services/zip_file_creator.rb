require 'zip/zip'

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

end

class LocalZipFileCreator < ZipFileCreator

  def create_zip
    zip
    chmod
  end

  def zip
    Zip::ZipFile.open(zipfile_name_and_path, Zip::ZipFile::CREATE) do |zipfile|
      files_to_zip.each do |filename_with_path|
        filename = filename_with_path.split('/').last
        zipfile.add(filename, filename_with_path)
      end
    end
  end

end

class SshZipFileCreator < ZipFileCreator

  def create_zip
    zip
    download_zip_from_remote_server
    remove_zip_file_on_remote_server
    chmod
  end

  def zip
    server.execute("zip --junk-paths #{remote_zip_name} #{files_to_zip.join(' ')}")
  end

  private

  def download_zip_from_remote_server
    server.copy_from_server(remote_zip_name, zipfile_name_and_path)
  end

  def remote_zip_name
    File.join("#{server.tf_dir}", "logs_and_demos_#{reservation.id}.zip")
  end

  def remove_zip_file_on_remote_server
    server.execute("rm #{remote_zip_name}")
  end

  def server
    reservation.server
  end

end
