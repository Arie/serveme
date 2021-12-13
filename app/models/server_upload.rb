# frozen_string_literal: true

class ServerUpload < ActiveRecord::Base
  belongs_to :server
  belongs_to :file_upload

  validates_presence_of :server_id, :file_upload_id
  validates_uniqueness_of :file_upload_id, scope: :server_id

  after_commit -> { broadcast_replace_to file_upload, target: "file_upload_#{file_upload.id}_server_#{server_id}", partial: 'server_uploads/server_upload', locals: { server_upload: self } }, on: %i[create update]

  def status
    return 'Upload complete' if uploaded_at
    return 'Upload started' if started_at

    'Waiting to upload'
  end
end
