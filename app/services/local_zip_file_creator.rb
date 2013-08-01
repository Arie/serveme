class LocalZipFileCreator < ZipFileCreator

  def create_zip
    zip
    chmod
  end

  def zip
    Zip::ZipFile.open(zipfile_name_and_path, Zip::ZipFile::CREATE) do |zipfile|
      files_to_zip.each do |filename_with_path|
        filename = File.basename(filename_with_path)
        zipfile.add(filename, filename_with_path)
      end
    end
  end

end
