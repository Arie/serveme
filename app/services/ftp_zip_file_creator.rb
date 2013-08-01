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
