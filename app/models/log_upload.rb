class LogUpload < ActiveRecord::Base

  attr_accessible :file_name, :title, :map_name, :status, :url

  belongs_to :reservation

  validates_presence_of :file_name, :reservation_id
  validate :validate_log_file_exists

  def self.find_log_files(reservation_id)
    log_match = File.join(Rails.root.join, 'server_logs', "#{reservation_id}", "L*.log")
    log_files = Dir.glob(log_match)
    logs = []
    log_files.each do |log_file|
      logs << { :file_name_and_path   => log_file,
                :file_name            => File.basename(log_file),
                :last_modified        => File.mtime(log_file),
                :size                 => File.size(log_file) }
    end
    logs
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

  private

  def logs_tf_api_key
    user.logs_tf_api_key || LOGS_TF_API_KEY
  end

  def log_file
    if log_file_exists?(file_name)
      File.open(Rails.root.join("server_logs", "#{reservation_id}", file_name))
    end
  end

  def validate_log_file_exists
    unless log_file_exists?(file_name)
      errors.add(:file_name, "file does not exist")
    end
  end

  def log_file_exists?(file_name)
    logs = LogUpload.find_log_files(self[:reservation_id])
    filenames = logs.map { |log| log[:file_name] }
    if filenames.include?(file_name)
      true
    end
  end

end
