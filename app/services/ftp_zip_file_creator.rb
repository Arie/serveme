class FtpZipFileCreator < ZipFileCreator

  def create_zip
    tmp_dir = Dir.mktmpdir
    begin
      reservation.status_update("Downloading logs and demos from FTP")
      server.copy_from_server(files_to_zip, tmp_dir)
      zip(tmp_dir)
      chmod
    ensure
      FileUtils.remove_entry tmp_dir
    end
  end

  def zip(tmp_dir)
    reservation.status_update("Zipping logs and demos")
    Zip::File.open(zipfile_name_and_path, Zip::File::CREATE) do |zipfile|
      files_to_zip_in_dir(tmp_dir).each do |filename_with_path|
        filename_without_path = File.basename(filename_with_path)
        zipfile.add(filename_without_path, filename_with_path)
      end
    end
  end

  def files_to_zip_in_dir(dir)
    Dir.glob(File.join(dir, "*"))
  end

end
