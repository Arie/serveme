# frozen_string_literal: true

class DownloadThenZipFileCreator < ZipFileCreator
  def create_zip
    tmp_dir = Dir.mktmpdir
    begin
      reservation.status_update('Downloading logs and demos from server')
      server.copy_from_server(files_to_zip, tmp_dir)
      reservation.status_update('Finished downloading logs and demos from server')
      strip_ips_and_api_keys_from_log_files(tmp_dir)
      zip(tmp_dir)
      chmod
    ensure
      FileUtils.remove_entry tmp_dir
    end
  end

  def strip_ips_and_api_keys_from_log_files(tmp_dir)
    strip_command = %q|LANG=ALL LC_ALL=C sed -i -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/0.0.0.0/g;s/logstf_apikey \"\S+\"/logstf_apikey \"apikey\"/g;s/tftrue_logs_apikey \"\S+\"/tftrue_logs_apikey \"apikey\"/g;s/sm_demostf_apikey \"\S+\"/sm_demostf_apikey \"apikey\"/g'|
    strip_files   = "#{tmp_dir}/*.log"
    system("#{strip_command} #{strip_files}")
  end

  def zip(tmp_dir)
    reservation.status_update('Zipping logs and demos')
    Zip::File.open(zipfile_name_and_path, Zip::File::CREATE) do |zipfile|
      files_to_zip_in_dir(tmp_dir).each do |filename_with_path|
        filename_without_path = File.basename(filename_with_path)
        zipfile.add(filename_without_path, filename_with_path)
      end
    end
    reservation.status_update('Finished zipping logs and demos')
  end

  def files_to_zip_in_dir(dir)
    Dir.glob(File.join(dir, '*'))
  end
end
