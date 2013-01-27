require 'zip/zip'
class ZipFile

  def self.create(zipfile_name_and_path, files_to_zip)
    Zip::ZipFile.open(zipfile_name_and_path, Zip::ZipFile::CREATE) do |zipfile|
      files_to_zip.each do |filename_with_path|
        filename = filename_with_path.split('/').last
        zipfile.add(filename, filename_with_path)
      end
    end
    chmod(zipfile_name_and_path)
  end

  def self.chmod(zipfile_name_and_path)
    File.chmod(0755, zipfile_name_and_path)
  end
end
