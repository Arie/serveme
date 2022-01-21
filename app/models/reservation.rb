# frozen_string_literal: true

class Reservation < ActiveRecord::Base
  belongs_to :user
  belongs_to :server
  belongs_to :server_config
  belongs_to :whitelist
  has_many :log_uploads
  has_many :reservation_players
  has_many :ratings
  has_many :reservation_statuses
  has_many :server_statistics

  before_validation :calculate_duration
  before_create :generate_logsecret
  after_create :generate_initial_status

  delegate :donator?, to: :user, prefix: false

  include ReservationServerInformation
  include ReservationValidations
  include Mitigations

  attr_accessor :extending, :rcon_command

  def self.with_user_and_server
    includes(user: :groups).includes(server: :location)
  end

  def self.ordered
    with_user_and_server.order('starts_at DESC')
  end

  def self.within_time_range(start_time, end_time)
    (where(starts_at: start_time...end_time).ordered +
     where(ends_at: start_time...end_time).ordered)
  end

  def self.future
    where('reservations.starts_at > ?', Time.current)
  end

  def self.current
    where('reservations.starts_at <= ? AND reservations.ends_at >= ?', Time.current, Time.current)
  end

  def to_s
    "#{id}: #{human_timerange}"
  end

  def human_timerange
    "#{I18n.l(starts_at, format: :datepicker)} - #{I18n.l(ends_at, format: :time)}"
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
    ends_at > 21.days.ago
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
    @own_colliding_reservations ||= CollisionFinder.new(Reservation.where(user_id: user.id), self).colliding_reservations
  end

  def other_users_colliding_reservations
    @other_users_colliding_reservations ||= CollisionFinder.new(Reservation.where(server_id: server.id), self).colliding_reservations
  end

  def collides_with_own_reservation?
    own_colliding_reservations.any?
  end

  def collides_with_other_users_reservation?
    other_users_colliding_reservations.any?
  end

  def extend!
    return unless less_than_1_hour_left? && !gameye?

    self.extending  = true
    self.ends_at    = ends_at + user.reservation_extension_time
    self.inactive_minute_counter = 0
    save
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
    time_left_text        = I18n.t(:timeleft, count: time_left_in_minutes)
    if gameye?
      server.rcon_say("This reservation will end in less than #{time_left_text}, it cannot be extended")
    else
      server.rcon_say("This reservation will end in less than #{time_left_text}, if this server is not yet booked by someone else, you can say !extend for more time")
    end
    server.rcon_disconnect
  end

  def cancellable?
    future?
  end

  def tv_password
    self[:tv_password].presence || 'tv'
  end

  def tv_relaypassword
    self[:tv_relaypassword].presence || self[:tv_password].presence || 'tv'
  end

  def formatted_starts_at
    starts_at.utc.strftime('%Y%m%d')
  end

  def inactive_too_long?
    inactive_minute_counter >= inactive_minute_limit
  end

  def inactive_minute_limit
    return 240 if user && (user.admin? || user.donator?)

    45
  end

  def custom_whitelist_content
    WhitelistTf.find_by_tf_whitelist_id(custom_whitelist_id).try(:content)
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
    attributes.slice('server_id', 'password', 'rcon', 'tv_password', 'server_config_id', 'whitelist_id', 'custom_whitelist_id', 'first_map', 'enable_plugins', 'enable_demos_tf')
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_binding
    binding
  end
  # rubocop:enable Naming/AccessorMethodName

  def times_entered?
    starts_at && ends_at
  end

  def status_update(status)
    reservation_statuses.create!(status: status)
  end

  def lobby?
    Rails.cache.fetch("reservation_#{id}_lobby") do
      tags = server.rcon_exec('sv_tags').to_s
      true if (tags && (tags.include?('TF2Center') || tags.include?('TF2Stadium'))) || tags.include?('TF2Pickup')
    end
  end

  def apply_api_keys
    server.rcon_exec("tftrue_logs_apikey \"#{user.logs_tf_api_key.presence || LOGS_TF_API_KEY}\"; sm_web_rcon_url \"#{SITE_URL}/reservations/#{id}/rcon\"; sm_demostf_apikey \"#{user.demos_tf_api_key.presence || DEMOS_TF_API_KEY}\"")
  end

  def status
    return 'Ended' if past?

    status_messages = reservation_statuses.pluck(:status)
    return 'Ended' if status_messages.include?('Finished zipping logs and demos')

    return 'Ending' if status_messages.include?('Ending')

    return 'SDR Ready' if sdr_ip.present?
    return 'Ready' if server_statistics.any? && !server.sdr?
    return 'Ready' if status_messages.grep(/\AServer finished loading map/).any? && !server.sdr?

    return 'Server updating, please be patient' if status_messages.grep(/\AServer outdated/).any?

    return 'Starting' if status_messages.include?('Starting')
    return 'Starting' if status_messages.grep(/\ACreated Gameye match/).any?

    return 'Waiting to start' if status_messages.include?('Waiting to start')

    'Unknown'
  end

  def poor_rcon_password?
    rcon.nil? || rcon.size < 8
  end

  def generate_rcon_password!
    self.rcon = FriendlyPasswordGenerator.generate
  end

  def whitelist_ip
    return user.current_sign_in_ip if user.current_sign_in_ip && IPAddr.new(user.current_sign_in_ip).ipv4?

    return user.reservation_players.last.ip if user.reservation_players.exists?

    "direct.#{SITE_HOST}"
  end

  def gameye?
    gameye_location.present? || server&.gameye?
  end

  def logs_tf_url
    "http://logs.tf/search/log?s=#{SITE_HOST}+%23#{id}"
  end

  def save_sdr_info(server_info)
    return if server_info.ip.nil?

    update_columns(
      sdr_ip: server_info.ip,
      sdr_port: server_info.port,
      sdr_tv_port: server_info.port + 1
    )
    server.update_columns(
      last_sdr_ip: server_info.ip,
      last_sdr_port: server_info.port,
      last_sdr_tv_port: server_info.port + 1
    )
    broadcast_connect_info
    status_update("SDR ready, server available at #{server_info.ip}:#{server_info.port}")
  end

  def broadcast_connect_info
    broadcast_replace_to self, target: "reservation_connect_info_#{id}", partial: 'reservations/connect_info', locals: { reservation: self }
    broadcast_replace_to self, target: "reservation_stv_connect_info_#{id}", partial: 'reservations/stv_connect_info', locals: { reservation: self }
    broadcast_replace_to self, target: "reservation_actions_#{id}", partial: 'reservations/actions', locals: { reservation: self }
  end

  private

  def reservation_manager
    ReservationManager.new(self)
  end

  def generate_initial_status
    status_update('Waiting to start') if future?
  end
end
