class LocalZipFileCreator < ZipFileCreator

  def create_zip
    zip
    chmod
  end

  def zip
    reservation.status_update("Zipping logs and demos of locally running server")
    Zip::File.open(zipfile_name_and_path, Zip::File::CREATE) do |zipfile|
      files_to_zip.each do |filename_with_path|
        filename = File.basename(filename_with_path)
        zipfile.add(filename, filename_with_path)
      end
    end
  end

end
