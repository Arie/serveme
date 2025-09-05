# typed: true
# frozen_string_literal: true

class ServerUpload < ActiveRecord::Base
  extend T::Sig

  belongs_to :server
  belongs_to :file_upload

  validates_presence_of :server_id, :file_upload_id
  validates_uniqueness_of :file_upload_id, scope: :server_id

  after_commit -> { T.unsafe(self).broadcast_replace_to T.unsafe(self).file_upload, target: "file_upload_#{T.unsafe(self).file_upload.id}_server_#{T.unsafe(self).server_id}", partial: "server_uploads/server_upload", locals: { server_upload: self } }, on: %i[create update]

  sig { returns(String) }
  def status
    return "Upload complete" if uploaded_at
    return "Upload started" if started_at

    "Waiting to upload"
  end
end
