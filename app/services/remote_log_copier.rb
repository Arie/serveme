class RemoteLogCopier < LogCopier

  def copy_logs
    zipfile_name_and_path = Rails.root.join("public", "uploads", reservation.zipfile_name)
    Zip::ZipFile.foreach(zipfile_name_and_path) do |zipped_file|
      if zipped_file.name.match("^.*\.log$")
        zipped_file.extract(File.join(directory_to_copy_to, zipped_file.name)) { true }
      end
    end
  end

end
