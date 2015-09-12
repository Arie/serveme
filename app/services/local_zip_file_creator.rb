class LocalZipFileCreator < ZipFileCreator

  def create_zip
    zip
    chmod
  end

  def zip
    reservation.status_update("Zipping logs and demos of locally running server")
    system("zip -j #{zipfile_name_and_path} #{shell_escaped_files_to_zip.join(' ')}")
  end

end
