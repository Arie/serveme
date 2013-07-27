class FtpZipFileCreator < ZipFileCreator

  def create_zip
    Dir.mktmpdir do |tmp_dir|
      server.copy_from_server(files_to_zip, tmp_dir)
      zip(tmp_dir)
    end
    chmod
  end

  def zip(tmp_dir)
    Zip::ZipFile.open(zipfile_name_and_path, Zip::ZipFile::CREATE) do |zipfile|
      Dir.glob(File.join(tmp_dir, "*")).each do |filename_with_path|
        filename_without_path = File.basename(filename_with_path)
        zipfile.add(filename_without_path, filename_with_path)
      end
    end
  end

  def zip_file_name
    "logs_and_demos_#{reservation.id}.zip"
  end

  private

  def server
    reservation.server
  end

  def shell_escaped_files_to_zip
    files_to_zip.collect { |file| file.shellescape }
  end

end
