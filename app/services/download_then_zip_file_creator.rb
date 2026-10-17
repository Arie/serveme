# typed: true
# frozen_string_literal: true

class DownloadThenZipFileCreator < ZipFileCreator
  extend T::Sig

  sig { void }
  def create_zip
    tmp_dir = Dir.mktmpdir
    begin
      fetch_files(tmp_dir)
      strip_ips_and_api_keys_from_log_files(tmp_dir)
      zip(tmp_dir)
      chmod
    ensure
      FileUtils.remove_entry tmp_dir
    end
  end

  sig { params(tmp_dir: String).void }
  def fetch_files(tmp_dir)
    reservation.status_update("Downloading logs and demos from server")
    server.copy_from_server(files_to_zip, tmp_dir)
    reservation.status_update("Finished downloading logs and demos from server")
  end

  IP_REGEX = /\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b/n
  API_KEY_REGEX = /(logstf_apikey|tftrue_logs_apikey|sm_demostf_apikey) "[^"]*"/n
  LOGSECRET_REGEX = /sv_logsecret \d+/n

  # Logs aren't guaranteed to be valid UTF-8, so work on the raw bytes
  sig { params(tmp_dir: String).void }
  def strip_ips_and_api_keys_from_log_files(tmp_dir)
    Dir.glob("#{tmp_dir}/*.log").each do |log_file|
      content = File.binread(log_file)
      stripped = content.gsub(IP_REGEX, "0.0.0.0")
                        .gsub(API_KEY_REGEX, '\1 "apikey"')
                        .gsub(LOGSECRET_REGEX, "sv_logsecret 0")
      File.binwrite(log_file, stripped) if stripped != content
    end
  rescue SystemCallError => e
    Rails.logger.error("Failed to strip IPs/API keys from logs: #{e.message}")
  end

  sig { params(tmp_dir: String).void }
  def zip(tmp_dir)
    reservation.status_update("Zipping logs and demos")
    Zip::File.open(zipfile_name_and_path, create: true) do |zipfile|
      files_to_zip_in_dir(tmp_dir).each do |filename_with_path|
        filename_without_path = File.basename(filename_with_path)
        begin
          zipfile.add(filename_without_path, filename_with_path)
        rescue Zip::EntryExistsError
          Rails.logger.info("Zipfile for reservation #{reservation.id} already had #{filename_with_path} in it, skipping")
        end
      end
    end
    reservation.status_update("Finished zipping logs and demos")
  end

  sig { params(dir: String).returns(T::Array[String]) }
  def files_to_zip_in_dir(dir)
    Dir.glob(File.join(dir, "*"))
  end
end
