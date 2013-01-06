require 'zip/zip'
class Reservation < ActiveRecord::Base
  has_paper_trail
  attr_accessible :server, :user, :server_id, :user_id, :password, :rcon, :tv_password, :tv_relaypassword, :starts_at, :ends_at, :provisioned, :ended
  belongs_to :user
  belongs_to :server
  validates_presence_of :user, :server, :date, :password, :rcon
  validate :validate_free_when_reserving
  validate :validate_reservable_by_user
  validate :validate_length_of_reservation
  validate :validate_chronologicality_of_times

  def self.within_12_hours
    within_time_range(12.hours.ago, 12.hours.from_now).uniq
  end

  def self.within_time_range(start_time, end_time)
    (where(:starts_at => start_time...end_time).order('starts_at DESC') +
     where(:ends_at => start_time...end_time).order('starts_at DESC'))
  end

  def self.future
    where('reservations.ends_at > ?', Time.now)
  end

  def self.upcoming
    where('reservations.starts_at > ?', Time.now)
  end

  def self.current
    where('reservations.starts_at < ? AND reservations.ends_at > ?', Time.now, Time.now)
  end

  def to_s
    "#{user.try(:nickname)}: #{I18n.l(starts_at, :format => :datepicker)} - #{I18n.l(ends_at, :format => :time)}"
  end

  def now?
    starts_at < Time.now && ends_at > Time.now
  end

  def active?
    now? && provisioned?
  end

  def past?
    ends_at < Time.now
  end

  def future?
    starts_at > Time.now
  end

  def collides?
    colliding_reservations.any?
  end

  def colliding_reservations
    (own_colliding_reservations + other_users_colliding_reservations).uniq
  end

  def own_colliding_reservations
    colliding_reservations_on(user)
  end

  def other_users_colliding_reservations
    colliding_reservations_on(server)
  end

  def colliding_reservations_on(collider)
    range = starts_at..ends_at
    front_rear_and_complete_colliding = (collider.reservations.where(:starts_at => range) + collider.reservations.where(:ends_at => range))
    internal_colliding                = collider.reservations.where('starts_at < ? AND ends_at > ?', starts_at, ends_at)
    colliding = (front_rear_and_complete_colliding + internal_colliding).uniq
    #If we're an existing record, remove ourselves from the colliding ones
    if persisted?
      colliding.reject { |r| r.id == id }
    else
      colliding
    end
  end

  def collides_with_own_reservation?
    own_colliding_reservations.any?
  end

  def collides_with_other_users_reservation?
    other_users_colliding_reservations.any?
  end

  def extend!
    if less_than_1_hour_left?
      @extending = true
      self.ends_at = ends_at + 1.hour
      save!
    end
  end

  def less_than_1_hour_left?
    time_left = (ends_at - Time.now)
    active? && time_left < 1.hour
  end

  def duration
    ends_at - starts_at
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
    begin
      server.update_configuration(self)
      server.restart
    rescue
      logger.error "Something went wrong provisioning the server for reservation #{self.id}"
    ensure
      self.provisioned = true
      save(:validate => false)
      logger.info "[#{Time.now}] Started reservation: #{id} #{self}"
    end
  end

  def end_reservation
    begin
      zip_demos_and_logs
      remove_configuration
    rescue
      logger.error "Something went wrong ending reservation #{self.id}"
    ensure
      self.ends_at  = Time.now
      self.ended    = true
      save(:validate => false)
      logger.info "[#{Time.now}] Ended reservation: #{id} #{self}"
    end
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
    log_match = File.join(server.path, 'orangebox', 'tf', 'logs', "L*.log")
    Dir.glob(log_match)
  end

  def demos
    demo_match = File.join(server.path, 'orangebox', 'tf', "*.dem")
    Dir.glob(demo_match)
  end

  def demo_date
    @demo_date ||= starts_at.strftime("%Y%m%d")
  end

  def zipfile_name
    "#{user.uid}-#{id}-#{server_id}-#{demo_date}.zip"
  end

  def get_binding
    binding
  end

  def validate_free_when_reserving
    if collides_with_own_reservation?
      msg = "you already have a reservation in this timeframe"
      errors.add(:starts_at, msg)
      errors.add(:ends_at,   msg)
    end
    if collides_with_other_users_reservation?
      errors.add(:server_id,  "already booked in the selected timeframe")
    end
  end

  def validate_reservable_by_user
    unless Server.reservable_by_user(user).include?(server)
      errors.add(:server_id, "is not available for you")
    end
  end

  def validate_length_of_reservation
    if duration > 3.hours && !@extending
      errors.add(:ends_at, "maximum reservation time is 3 hours")
    end
  end

  def validate_chronologicality_of_times
    if (starts_at + 30.minutes) > ends_at
      errors.add(:ends_at, "needs to be at least 30 minutes after start time")
    end
  end

end
