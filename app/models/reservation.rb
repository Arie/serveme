class Reservation < ActiveRecord::Base
  has_paper_trail
  attr_accessible :server, :user, :server_id, :user_id, :password, :rcon, :tv_password, :tv_relaypassword, :starts_at, :disable_source_tv,
                  :ends_at, :provisioned, :ended, :server_config, :server_config_id, :whitelist, :whitelist_id, :inactive_minute_counter
  belongs_to :user
  belongs_to :server
  belongs_to :server_config
  belongs_to :whitelist
  belongs_to :reservation
  has_many :log_uploads
  validates_presence_of :user, :server, :password, :rcon
  validate :validate_user_is_available
  validate :validate_server_is_available,   :if     => :server
  validate :validate_reservable_by_user
  validate :validate_length_of_reservation, :unless => :extending
  validate :validate_chronologicality_of_times
  validate :validate_starts_at_not_too_far_in_past, :on => :create

  attr_accessor :extending

  def self.within_12_hours
    within_time_range(12.hours.ago, 12.hours.from_now).uniq
  end

  def self.ordered
    order('starts_at DESC')
  end

  def self.within_time_range(start_time, end_time)
    (where(:starts_at => start_time...end_time).ordered +
     where(:ends_at => start_time...end_time).ordered)
  end

  def self.future
    where('reservations.ends_at > ?', Time.current)
  end

  def self.current
    where('reservations.starts_at < ? AND reservations.ends_at > ?', Time.current, Time.current)
  end

  def to_s
    "#{user.try(:nickname)}: #{I18n.l(starts_at, :format => :datepicker)} - #{I18n.l(ends_at, :format => :time)}"
  end

  def now?
    starts_at < Time.current && ends_at > Time.current
  end

  def active?
    now? && provisioned?
  end

  def past?
    ends_at < Time.current
  end

  def future?
    starts_at > Time.current
  end

  def collides?
    colliding_reservations.any?
  end

  def colliding_reservations
    (own_colliding_reservations + other_users_colliding_reservations).uniq
  end

  def own_colliding_reservations
    @own_colliding_reservations ||= CollisionFinder.new(user, self).colliding_reservations
  end

  def other_users_colliding_reservations
    @other_users_colliding_reservations ||= CollisionFinder.new(server, self).colliding_reservations
  end

  def collides_with_own_reservation?
    own_colliding_reservations.any?
  end

  def collides_with_other_users_reservation?
    other_users_colliding_reservations.any?
  end

  def extend!
    if less_than_1_hour_left?
      self.extending  = true
      self.ends_at    = ends_at + 1.hour
      save!
    end
  end

  def less_than_1_hour_left?
    time_left = (ends_at - Time.current)
    active? && time_left < 1.hour
  end

  def cancellable?
    future? || (now? && !provisioned?)
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

  def connect_string
    server.server_connect_string(password)
  end

  def stv_connect_string
    server.stv_connect_string(tv_password)
  end

  def server_connect_url
    server.server_connect_url(password)
  end

  def stv_connect_url
    server.stv_connect_url(tv_password)
  end

  def start_reservation
    begin
      server.start_reservation(self)
    rescue Exception => exception
      logger.error "Something went wrong provisioning the server for reservation #{self.id} - #{exception}"
      Raven.capture_exception(exception) if Rails.env.production?
    ensure
      self.provisioned = true
      save(:validate => false)
      logger.info "[#{Time.now}] Started reservation: #{id} #{self}"
    end
  end

  def end_reservation
    unless ended?
      begin
        server.end_reservation(self)
      rescue Exception => exception
        logger.error "Something went wrong ending reservation #{self.id} - #{exception}"
        Raven.capture_exception(exception) if Rails.env.production?
      ensure
        self.ends_at  = Time.current
        self.ended    = true
        save(:validate => false)
        logger.info "[#{Time.now}] Ended reservation: #{id} #{self}"
      end
    end
  end

  def zipfile_name
    "#{user.uid}-#{id}-#{server.id}-#{formatted_starts_at}.zip"
  end

  def inactive_too_long?
    inactive_minute_counter >= 30
  end

  def formatted_starts_at
    starts_at.strftime("%Y%m%d")
  end

  def get_binding
    binding
  end

  def validate_user_is_available
    if collides_with_own_reservation?
      msg = "you already have a reservation in this timeframe"
      errors.add(:starts_at, msg)
      errors.add(:ends_at,   msg)
    end
  end

  def validate_server_is_available
    if collides_with_other_users_reservation?
      errors.add(:server_id,  "already booked in the selected timeframe")
    end
  end

  def validate_reservable_by_user
    unless Server.reservable_by_user(user).map(&:id).include?(server_id)
      errors.add(:server_id, "is not available for you")
    end
  end

  def validate_length_of_reservation
    if duration > 3.hours
      errors.add(:ends_at, "maximum reservation time is 3 hours")
    end
  end

  def validate_starts_at_not_too_far_in_past
    if starts_at && starts_at < 15.minutes.ago
      errors.add(:starts_at, "can't be more than 15 minutes in the past")
    end
  end

  def validate_chronologicality_of_times
    if (starts_at + 30.minutes) > ends_at
      errors.add(:ends_at, "needs to be at least 30 minutes after start time")
    end
  end

end
