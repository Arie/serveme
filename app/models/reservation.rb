class Reservation < ActiveRecord::Base
  attr_accessible :server, :user, :server_id, :user_id, :password, :rcon, :tv_password, :tv_relaypassword, :starts_at, :disable_source_tv,
                  :ends_at, :provisioned, :ended, :server_config, :server_config_id, :whitelist, :whitelist_id, :inactive_minute_counter, 
                  :first_map
  has_paper_trail
  belongs_to :user
  belongs_to :server
  belongs_to :server_config
  belongs_to :whitelist
  belongs_to :reservation
  has_many :log_uploads

  delegate :donator?, :to => :user, :prefix => false

  validates_presence_of :user, :server, :password, :rcon
  validates_with Reservations::UserIsAvailableValidator
  validates_with Reservations::ServerIsAvailableValidator
  validates_with Reservations::ReservableByUserValidator
  validates_with Reservations::LengthOfReservationValidator
  validates_with Reservations::ChronologicalityOfTimesValidator
  validates_with Reservations::StartsNotTooFarInPastValidator,            :on => :create
  validates_with Reservations::OnlyOneFutureReservationPerUserValidator,  :unless => :donator?
  validates_with Reservations::StartsNotTooFarInFutureValidator,          :unless => :donator?

  validate :validate_first_map_is_not_mvm

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

  def self.ending_in_future
    where('reservations.ends_at > ?', Time.current)
  end

  def self.future
    where('reservations.starts_at > ?', Time.current)
  end

  def self.current
    where('reservations.starts_at <= ? AND reservations.ends_at >= ?', Time.current, Time.current)
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

  def schedulable?
    !persisted? || (persisted? && !active?)
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
      self.ends_at    = ends_at + user.reservation_extension_time
      save
    end
  end

  def less_than_1_hour_left?
    time_left = (ends_at - Time.current)
    active? && time_left < 1.hour
  end

  def just_started?
    starts_at > 3.minutes.ago
  end

  def nearly_over?
    time_left < 10.minutes
  end

  def time_left
    ends_at - Time.current
  end

  def warn_nearly_over
    time_left_in_minutes  = (time_left / 60.0).ceil
    time_left_text        = I18n.t(:timeleft, :count => time_left_in_minutes)
    server.rcon_say("This reservation will end in less than #{time_left_text}, if you need more time, extend your reservation on the website.")
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

  def rcon_string
    "rcon_address #{server.ip}:#{server.port}; rcon_password #{rcon}"
  end

  def server_connect_url
    server.server_connect_url(password)
  end

  def stv_connect_url
    server.stv_connect_url(tv_password)
  end

  def start_reservation
    ReservationManager.new(self).start_reservation
  end

  def end_reservation
    ReservationManager.new(self).end_reservation
  end

  def update_reservation
    ReservationManager.new(self).update_reservation
  end

  def zipfile_name
    "#{user.uid}-#{id}-#{server.id}-#{formatted_starts_at}.zip"
  end

  def formatted_starts_at
    starts_at.strftime("%Y%m%d")
  end

  def inactive_too_long?
    inactive_minute_counter >= inactive_minute_limit
  end

  def inactive_minute_limit
    if user && user.donator?
      60
    else
      30
    end
  end

  def has_players?
    last_number_of_players.to_i > 0
  end

  def very_short?
    duration < 15.minutes
  end

  def get_binding
    binding
  end

  def validate_first_map_is_not_mvm
    if first_map && first_map.match(/mvm_.*/)
      errors.add(:first_map, "you can't play MvM on our servers")
    end
  end

end
