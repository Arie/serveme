class LogUpload < ActiveRecord::Base

  attr_accessible :file_name, :title, :map_name, :status, :url

  belongs_to :reservation

  validates_presence_of :file_name, :reservation_id
  validate :validate_log_file_exists

  def self.find_log_files(reservation_id)
    log_files = Dir.glob(log_matcher(reservation_id))
    log_files.collect do |log_file|
      {
        :file_name_and_path   => log_file,
        :file_name            => File.basename(log_file),
        :last_modified        => File.mtime(log_file),
        :size                 => File.size(log_file)
      }
    end
  end

  def self.log_matcher(reservation_id)
    File.join(Rails.root.join, 'server_logs', "#{reservation_id}", "L*.log")
  end

  def upload
    logs_tf_log     = LogsTF::Log.new(log_file, map_name, title, logs_tf_api_key)
    logs_tf_upload  = LogsTF::Upload.new(logs_tf_log)
    begin
      logs_tf_upload.send
      message = 'success'
      url     = logs_tf_upload.url
    rescue Exception => e
      message = e.message
    ensure
      update_attributes(:status => message, :url => url.to_s)
    end
  end

  def log_file
    if log_file_exists?(file_name)
      File.open(log_file_name_and_path)
    end
  end

  def logs_tf_api_key
    user.logs_tf_api_key || LOGS_TF_API_KEY
  end

  def log_file_exists?(file_name)
    filenames.include?(file_name)
  end

  def log_file_name_and_path
    Rails.root.join("server_logs", "#{reservation_id}", file_name)
  end

  private

  def user
    reservation.user
  end

  def filenames
    logs.map { |log| log[:file_name] }
  end

  def logs
    LogUpload.find_log_files(reservation_id)
  end

  def validate_log_file_exists
    unless log_file_exists?(file_name)
      errors.add(:file_name, "file does not exist")
    end
  end

end
