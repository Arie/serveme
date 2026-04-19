# typed: false
# frozen_string_literal: true

class UploadFilesToServerWorker
  include Sidekiq::Worker

  def perform(options)
    files_with_path = options["files_with_path"]
    server_upload = ServerUpload.find_by_id(options["server_upload_id"])
    s = Server.find(server_upload.server_id)

    server_upload.update(started_at: Time.now)
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

      s.copy_to_server(files, full_path)
    end
    server_upload.update(uploaded_at: Time.now)
  end
end
