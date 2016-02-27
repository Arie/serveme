# frozen_string_literal: true
class Reservation < ActiveRecord::Base
  attr_accessible :server, :user, :server_id, :user_id, :password, :rcon, :tv_password, :tv_relaypassword, :starts_at,
                  :ends_at, :provisioned, :ended, :server_config, :server_config_id, :whitelist, :whitelist_id, :inactive_minute_counter,
                  :first_map, :custom_whitelist_id, :auto_end, :enable_plugins
  belongs_to :user
  belongs_to :server
  belongs_to :server_config
  belongs_to :whitelist
  has_many :log_uploads
  has_many :reservation_players
  has_many :ratings
  has_many :reservation_statuses

  before_validation :calculate_duration
  before_create :generate_logsecret
  after_create :generate_initial_status

  delegate :donator?, :to => :user, :prefix => false

  include ReservationValidations, ReservationServerInformation

  attr_accessor :extending

  def self.with_user_and_server
    includes(:user => :groups).includes(:server => :location)
  end

  def self.ordered
    with_user_and_server.order('starts_at DESC')
  end

  def self.within_time_range(start_time, end_time)
    (where(:starts_at => start_time...end_time).ordered +
     where(:ends_at => start_time...end_time).ordered)
  end

  def self.future
    where('reservations.starts_at > ?', Time.current)
  end

  def self.current
    where('reservations.starts_at <= ? AND reservations.ends_at >= ?', Time.current, Time.current)
  end

  def to_s
    "#{id} #{user.try(:nickname)}: #{human_timerange}"
  end

  def human_timerange
    "#{I18n.l(starts_at, :format => :datepicker)} - #{I18n.l(ends_at, :format => :time)}"
  end

  def now?
    times_entered? && (starts_at < Time.current && ends_at > Time.current)
  end

  def active?
    now? && provisioned?
  end

  def past?
    ends_at && ends_at <= Time.current
  end

  def younger_than_cleanup_age?
    ends_at > 28.days.ago
  end

  def future?
    starts_at > Time.current
  end

  def schedulable?
    !persisted? || (persisted? && !active? && !past?)
  end

  def collides?
    colliding_reservations.any?
  end

  def colliding_reservations
    (own_colliding_reservations + other_users_colliding_reservations).uniq
  end

  def own_colliding_reservations
    @own_colliding_reservations ||= CollisionFinder.new(Reservation.where(:user_id => user.id), self).colliding_reservations
  end

  def other_users_colliding_reservations
    @other_users_colliding_reservations ||= CollisionFinder.new(Reservation.where(:server_id => server.id), self).colliding_reservations
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
      self.inactive_minute_counter = 0
      save
    end
  end

  def less_than_1_hour_left?
    active? && time_left < 1.hour
  end

  def just_started?
    starts_at > 1.minute.ago
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
    server.rcon_say("This reservation will end in less than #{time_left_text}, if this server is not yet booked by someone else, you can say !extend for more time")
    server.rcon_disconnect
  end

  def cancellable?
    future? || (now? && !provisioned?)
  end

  def tv_password
    self[:tv_password].presence || 'tv'
  end

  def tv_relaypassword
    self[:tv_relaypassword].presence || 'tv'
  end

  def formatted_starts_at
    starts_at.utc.strftime("%Y%m%d")
  end

  def inactive_too_long?
    inactive_minute_counter >= inactive_minute_limit
  end

  def inactive_minute_limit
    if user
      return 240  if user.admin?
      return 60   if user.donator?
    end
    30
  end

  def calculate_duration
    self.duration = (ends_at.to_i - starts_at.to_i)
  end

  def generate_logsecret
    self.logsecret ||= rand(2**128)
  end

  def self.played_in(steam_uid)
    joins(:reservation_players).where('reservation_players.steam_uid = ? AND reservations.starts_at > ? AND reservations.ended = ?', steam_uid, 31.days.ago, true).ordered
  end

  def start_reservation
    reservation_manager.start_reservation
  end

  def update_reservation
    reservation_manager.update_reservation
  end

  def end_reservation
    reservation_manager.end_reservation
  end

  def reusable_attributes
    attributes.slice("server_id", "password", "rcon", "tv_password", "server_config_id", "whitelist_id", "custom_whitelist_id", "first_map", "enable_plugins")
  end

  def get_binding
    binding
  end

  def times_entered?
    starts_at && ends_at
  end

  def status_update(status)
    reservation_statuses.create!(:status => status)
  end

  def lobby?
    tags = server.rcon_exec("sv_tags")
    tags && (tags.include?("TF2Center") || tags.include?("TF2Stadium")) || tags.include?("TF2Pickup")
  end

  private

  def reservation_manager
    ReservationManager.new(self)
  end

  def generate_initial_status
    status_update("Waiting to start")
  end

end
