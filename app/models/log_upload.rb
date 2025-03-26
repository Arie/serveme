# typed: true
# frozen_string_literal: true

class LogUpload < ActiveRecord::Base
  extend T::Sig
  belongs_to :reservation

  validates_presence_of :reservation_id
  validates_presence_of :file_name,   unless: :tftrue_upload?
  validate :validate_log_file_exists, unless: :tftrue_upload?

  sig { params(reservation_id: T.any(String, Integer)).returns(T::Array[Hash]) }
  def self.find_log_files(reservation_id)
    log_files = Dir.glob(log_matcher(reservation_id))
    files = log_files.collect do |log_file|
      {
        file_name_and_path: log_file,
        file_name: File.basename(log_file),
        last_modified: File.mtime(log_file),
        size: File.size(log_file)
      }
    end
    files.select do |log_file|
      log_file[:size] > 15.kilobytes
    end
  end

  sig { params(reservation_id: T.any(String, Integer)).returns(String) }
  def self.log_matcher(reservation_id)
    File.join(Rails.root.join, "server_logs", reservation_id.to_s, "*.log")
  end

  def upload
    logs_tf_log     = LogsTF::Log.new(log_file, map_name, title, logs_tf_api_key)
    logs_tf_upload  = LogsTF::Upload.new(logs_tf_log)
    begin
      logs_tf_upload.send
      message = "success"
      url     = logs_tf_upload.url
    rescue StandardError => e
      message = e.message
    ensure
      update(status: message, url: url.to_s)
    end
  end

  sig { returns(T.nilable(File)) }
  def log_file
    File.open(log_file_name_and_path) if log_file_and_name_present?
  end

  sig { returns(T.nilable(String)) }
  def logs_tf_api_key
    user.logs_tf_api_key.presence || Rails.application.credentials.dig(:logs_tf, :api_key)
  end

  sig { params(file_name: String).returns(T::Boolean) }
  def log_file_exists?(file_name)
    filenames.include?(file_name)
  end

  sig { returns(Pathname) }
  def log_file_name_and_path
    Rails.root.join("server_logs", reservation_id.to_s, T.must(file_name))
  end

  private

  def log_file_and_name_present?
    file_name && log_file_exists?(T.must(file_name))
  end

  def user
    reservation&.user
  end

  def filenames
    logs.map { |log| log[:file_name] }
  end

  def logs
    LogUpload.find_log_files(T.must(reservation_id))
  end

  def validate_log_file_exists
    return if log_file_and_name_present?

    errors.add(:file_name, "file does not exist")
  end

  def tftrue_upload?
    status == "TFTrue upload"
  end
end
