# frozen_string_literal: true
class SshZipFileCreator < ZipFileCreator

  def create_zip
    zip
    download_zip_from_remote_server
    remove_zip_file_on_remote_server
    chmod
  end

  def zip
    reservation.status_update("Telling server to zip logs and demos")
    server.execute("zip -j #{remote_zip_name} #{shell_escaped_files_to_zip.join(' ')}")
  end

  def download_zip_from_remote_server
    reservation.status_update("Downloading logs and demos zip from server")
    Rails.logger.info "Downloading #{remote_zip_name} from #{server.name}"
    server.copy_from_server([remote_zip_name], zipfile_name_and_path)
  end

  def remote_zip_name
    File.join("#{server.tf_dir}", "logs_and_demos_#{reservation.id}.zip")
  end

  def remove_zip_file_on_remote_server
    server.execute("rm #{remote_zip_name}")
  end

end
