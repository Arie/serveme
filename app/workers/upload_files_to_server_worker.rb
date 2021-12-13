# frozen_string_literal: true

class UploadFilesToServerWorker
  include Sidekiq::Worker

  def perform(options)
    files_with_path = options['files_with_path']
    server_upload = ServerUpload.find_by_id(options['server_upload_id'])
    s = Server.find(server_upload.server_id)

    server_upload.update(started_at: Time.now)
    files_with_path.each do |destination, files|
      s.copy_to_server(files, File.join(s.tf_dir, destination)) if files.any?
    end
    server_upload.update(uploaded_at: Time.now)
  end
end
