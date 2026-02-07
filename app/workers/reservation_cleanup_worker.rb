# typed: true
# frozen_string_literal: true

require "fileutils"
require "safe_file_deletion"

class ReservationCleanupWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: "default"

  attr_accessor :reservation, :server, :temp_directory_path

  def perform(reservation_id, temp_directory_path)
    @reservation = Reservation.includes(:server).find(reservation_id)
    @server = @reservation.server
    @temp_directory_path = temp_directory_path

    return unless @server

    begin
      zip_files
      copy_logs_to_destination
      LogScanWorker.perform_async(reservation_id)
      cleanup_temp_directory
      Rails.logger.info("ReservationCleanupWorker: Completed cleanup for reservation #{reservation_id}")
    rescue StandardError => e
      Rails.logger.error("ReservationCleanupWorker: Error processing reservation #{reservation_id}: #{e.message}\n#{T.must(e.backtrace).join("\n")}")
      raise
    end
  end

  private

  def zip_files
    # Only LocalServer and SshServer use async cleanup
    # FTP-based RemoteServers use synchronous cleanup in Server#end_reservation
    if server.is_a?(LocalServer)
      zip_local_server_files
    elsif server.is_a?(SshServer)
      zip_ssh_server_files
    else
      raise "Unexpected server type: #{server.class.name}. Only LocalServer and SshServer use async cleanup."
    end
  end

  def zip_local_server_files
    # For local servers, zip files directly from local temp directory
    reservation.status_update("Zipping logs and demos of locally running server")
    files_in_temp_dir = Dir.glob(File.join(temp_directory_path, "*"))
    return if files_in_temp_dir.empty?

    # Strip IPs and API keys from log files before zipping
    strip_ips_and_api_keys_from_log_files(temp_directory_path)

    zipfile_name_and_path = Rails.root.join("public", "uploads", reservation.zipfile_name).to_s

    # Remove existing zipfile to ensure idempotency on retry
    FileUtils.rm_f(zipfile_name_and_path) if File.exist?(zipfile_name_and_path)

    # brakeman: ignore:Command Injection - zipfile_name_and_path is controlled by the application and files are escaped
    system("zip -j #{zipfile_name_and_path.shellescape} #{files_in_temp_dir.map(&:shellescape).join(' ')}")
    File.chmod(0o755, zipfile_name_and_path)
  end

  def zip_ssh_server_files
    local_tmp_dir = Dir.mktmpdir
    begin
      reservation.status_update("Downloading logs and demos from server")

      files_in_temp_dir = glob_files_in_remote_temp_directory
      return if files_in_temp_dir.empty?

      server.copy_from_server(files_in_temp_dir, local_tmp_dir)
      reservation.status_update("Finished downloading logs and demos from server")

      strip_ips_and_api_keys_from_log_files(local_tmp_dir)

      zip_downloaded_files(local_tmp_dir)
    ensure
      FileUtils.remove_entry(local_tmp_dir)
    end
  end

  def glob_files_in_remote_temp_directory
    # List all files in the remote temp directory
    result = server.execute("ls #{temp_directory_path.shellescape}/*.* 2>/dev/null || true")
    result.split("\n").map(&:strip).reject(&:empty?)
  rescue StandardError => e
    Rails.logger.error("ReservationCleanupWorker: Error listing files in temp directory: #{e.message}")
    []
  end

  def strip_ips_and_api_keys_from_log_files(tmp_dir)
    strip_command = %q|LANG=ALL LC_ALL=C sed -i -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/0.0.0.0/g;s/logstf_apikey \"\S+\"/logstf_apikey \"apikey\"/g;s/tftrue_logs_apikey \"\S+\"/tftrue_logs_apikey \"apikey\"/g;s/sm_demostf_apikey \"\S+\"/sm_demostf_apikey \"apikey\"/g'|
    strip_files = "#{tmp_dir}/*.log"
    # brakeman: ignore:Command Injection - tmp_dir is created by Dir.mktmpdir and strip_command is a static string
    system("#{strip_command} #{strip_files}")
  end

  def zip_downloaded_files(tmp_dir)
    reservation.status_update("Zipping logs and demos")
    zipfile_name_and_path = Rails.root.join("public", "uploads", reservation.zipfile_name).to_s

    FileUtils.rm_f(zipfile_name_and_path) if File.exist?(zipfile_name_and_path)

    Zip::File.open(zipfile_name_and_path, create: true) do |zipfile|
      Dir.glob(File.join(tmp_dir, "*")).each do |filename_with_path|
        filename_without_path = File.basename(filename_with_path)
        zipfile.add(filename_without_path, filename_with_path)
      end
    end

    File.chmod(0o755, zipfile_name_and_path)
    reservation.status_update("Finished zipping logs and demos")
  end

  def copy_logs_to_destination
    LogCopier.copy(reservation, server)
  end

  def cleanup_temp_directory
    if server.is_a?(LocalServer)
      cleanup_local_temp_directory
    elsif server.is_a?(SshServer)
      cleanup_remote_temp_directory
    else
      raise "Unexpected server type: #{server.class.name}. Only LocalServer and SshServer use async cleanup."
    end
  end

  def cleanup_local_temp_directory
    SafeFileDeletion.safe_remove_directory(temp_directory_path)
  rescue SafeFileDeletion::InvalidPathError => e
    Rails.logger.error("ReservationCleanupWorker: Invalid temp directory path #{temp_directory_path}: #{e.message}")
    raise
  end

  def cleanup_remote_temp_directory
    SafeFileDeletion.validate_temp_directory!(temp_directory_path)
    server.execute("rm -rf #{temp_directory_path.shellescape}")
  rescue SafeFileDeletion::InvalidPathError => e
    Rails.logger.error("ReservationCleanupWorker: Invalid remote temp directory path #{temp_directory_path}: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("ReservationCleanupWorker: Error removing temp directory #{temp_directory_path}: #{e.message}")
  end
end
