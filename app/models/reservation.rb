require 'zip/zip'
class Reservation < ActiveRecord::Base
  attr_accessible :server_id, :user_id, :date, :password, :rcon, :tv_password, :tv_relaypassword
  belongs_to :user
  belongs_to :server
  validates_presence_of :user_id, :server_id, :date, :password, :rcon
  validates_uniqueness_of :user_id, :scope => :date, :message => "already made a reservation today"
  validate :validate_free_when_reserving
  validate :validate_reservable_by_user

  delegate :name, :to => :server, :prefix => true

  def self.today
    where(:date => Date.today)
  end

  def self.yesterday
    where(:date => Date.yesterday)
  end

  def date
    self[:date].presence || Date.today
  end

  def tv_password
    self[:tv_password].presence || 'tv'
  end

  def tv_relaypassword
    self[:tv_relaypassword].presence || 'tv'
  end

  def server_name
    "#{server.name} (#{user.nickname})"
  end

  def server_info
    "#{server.info} #{password}"
  end

  def connect_string
    "connect #{server.ip}:#{server.port}; password #{password}"
  end

  def steam_connect_url
    "steam://connect/#{server.ip}:#{server.port}/#{password}"
  end

  def update_configuration
    server.update_configuration(self)
    server.restart
  end

  def end_reservation
    zip_demos_and_logs
    remove_configuration
    destroy
  end

  def remove_configuration
    server.remove_configuration
    server.restart
  end

  def zip_demos_and_logs
    input_filenames = demos + logs

    zipfile_name_and_path = Rails.root.join("public", "uploads", zipfile_name)

    Zip::ZipFile.open(zipfile_name_and_path, Zip::ZipFile::CREATE) do |zipfile|
      input_filenames.each do |filename_with_path|
        filename = filename_with_path.split('/').last
        zipfile.add(filename, filename_with_path)
      end
    end
    File.chmod(0755, zipfile_name_and_path)

    logger.info "Removing logs and demos"
    logger.info input_filenames
    FileUtils.rm(input_filenames)
  end

  def logs
    log_match = File.join(server.path, 'orangebox', 'tf', 'logs', "L#{log_date}*.log")
    Dir.glob(log_match)
  end

  def demos
    demo_match = File.join(server.path, 'orangebox', 'tf', "auto-#{demo_date}*.dem")
    Dir.glob(demo_match)
  end

  def demo_date
    @demo_date ||= date.strftime("%Y%m%d")
  end

  def log_date
    @log_date  ||= date.strftime("%m%d")
  end

  def zipfile_name
    "#{user.uid}-#{id}-#{server_id}-#{demo_date}.zip"
  end

  def get_binding
    binding
  end

  def validate_free_when_reserving
    if Server.already_reserved_today.include?(server) && !server.reserved_today_by?(user)
      errors.add(:server_id, "is no longer available")
    end
  end

  def validate_reservable_by_user
    unless Server.reservable_by_user(user).include?(server)
      errors.add(:server_id, "is not available for you")
    end
  end

end
