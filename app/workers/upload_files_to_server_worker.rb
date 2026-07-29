# typed: true
# frozen_string_literal: true

class UploadFilesToServerWorker
  include Sidekiq::Worker
  extend T::Sig

  class UploadFailedError < StandardError; end

  sig { params(options: T::Hash[String, T.untyped]).void }
  def perform(options)
    server_upload = T.must(ServerUpload.find_by(id: options["server_upload_id"]))
    file_upload = T.must(server_upload.file_upload)
    s = Server.find(T.must(server_upload.server_id))

    server_upload.update(started_at: Time.now)
    files_with_path = file_upload.files_to_upload
    tf_dir = File.expand_path(s.tf_dir)

    directories = files_with_path.keys.filter_map do |destination|
      full_path = File.expand_path(File.join(tf_dir, destination))
      full_path if full_path.start_with?("#{tf_dir}/")
    end
    s.ensure_directories(directories) if directories.any?

    files_with_path.each do |destination, files|
      next unless files.any?

      full_path = File.expand_path(File.join(tf_dir, destination))
      next unless full_path.start_with?("#{tf_dir}/")

      result = s.copy_to_server(files, full_path)
      raise UploadFailedError, "Failed to copy #{files.size} file(s) to #{s.name}:#{full_path}" if result == false || result.nil?
    end
    server_upload.update(uploaded_at: Time.now)
  ensure
    file_upload&.cleanup_tmp_dir
  end
end
