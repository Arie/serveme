# typed: true
# frozen_string_literal: true

class Reservation < ActiveRecord::Base
  extend T::Sig

  belongs_to :user, counter_cache: true
  belongs_to :server, counter_cache: true
  belongs_to :server_config, optional: true
  belongs_to :whitelist, optional: true
  has_many :log_uploads
  has_many :reservation_players
  has_many :ratings
  has_many :reservation_statuses
  has_many :server_statistics
  has_many :stac_logs
  has_one_attached :zipfile, service: :seaweedfs

  before_validation :calculate_duration
  before_create :generate_logsecret
  after_create :generate_initial_status
  after_create :update_user_total_seconds_counter
  after_update :update_user_total_seconds_counter, if: :saved_change_to_duration?
  after_destroy :update_user_total_seconds_counter

  delegate :donator?, to: :user, prefix: false

  include ReservationServerInformation
  include ReservationValidations
  include Mitigations

  attr_accessor :extending, :rcon_command

  sig { returns(Integer) }
  def self.cleanup_age_in_days
    (SITE_HOST == "au.serveme.tf" && 7) || 30
  end

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.with_user_and_server
    includes(user: :groups).includes(server: :location)
  end

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.ordered
    with_user_and_server.order(starts_at: :desc)
  end

  sig { params(start_time: ActiveSupport::TimeWithZone, end_time: ActiveSupport::TimeWithZone).returns(Array) }
  def self.within_time_range(start_time, end_time)
    (ordered.where(starts_at: start_time...end_time) +
     ordered.where(ends_at: start_time...end_time))
  end

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.future
    where(starts_at: Time.current..)
  end

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.current
    where(starts_at: ..Time.current).where(ends_at: Time.current..)
  end

  def to_s
    "#{id}: #{human_timerange}"
  end

  def human_timerange
    "#{I18n.l(starts_at, format: :datepicker)} - #{I18n.l(ends_at, format: :time)}"
  end

  def now?
    times_entered? && T.must(starts_at) < Time.current && T.must(ends_at) > Time.current
  end

  def active?
    now? && provisioned?
  end

  def past?
    ends_at && T.must(ends_at) <= Time.current
  end

  def younger_than_cleanup_age?
    T.must(ends_at) > self.class.cleanup_age_in_days.days.ago
  end

  def future?
    T.must(starts_at) > Time.current
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
    @own_colliding_reservations ||= CollisionFinder.new(Reservation.where(user_id: user&.id), self).colliding_reservations
  end

  def other_users_colliding_reservations
    @other_users_colliding_reservations ||= CollisionFinder.new(Reservation.where(server_id: server&.id), self).colliding_reservations
  end

  def collides_with_own_reservation?
    own_colliding_reservations.any?
  end

  def collides_with_own_reservation_on_same_server?
    own_colliding_reservations.any? { |r| r.server_id == server_id }
  end

  def collides_with_other_users_reservation?
    other_users_colliding_reservations.any?
  end

  def extend!
    return unless less_than_1_hour_left?

    self.extending  = true
    self.ends_at    = T.must(ends_at) + user&.reservation_extension_time
    self.inactive_minute_counter = 0
    save
  end

  def less_than_1_hour_left?
    active? && time_left < 1.hour
  end

  def just_started?
    T.must(starts_at) > 1.minute.ago
  end

  def nearly_over?
    time_left < 10.minutes
  end

  def time_left
    T.must(ends_at) - Time.current
  end

  def warn_nearly_over
    time_left_in_minutes  = (time_left / 60.0).ceil
    time_left_text        = I18n.t(:timeleft, count: time_left_in_minutes)
    server&.rcon_say("This reservation will end in less than #{time_left_text}, if this server is not yet booked by someone else, you can say !extend for more time")
    server&.rcon_disconnect
  end

  def cancellable?
    future?
  end

  sig { returns(String) }
  def tv_password
    self[:tv_password].presence || "tv"
  end

  sig { returns(String) }
  def tv_relaypassword
    self[:tv_relaypassword].presence || self[:tv_password].presence || "tv"
  end

  sig { returns(String) }
  def formatted_starts_at
    T.must(starts_at).utc.strftime("%Y%m%d")
  end

  sig { returns(T::Boolean) }
  def inactive_too_long?
    inactive_minute_counter.to_i >= inactive_minute_limit
  end

  sig { returns(Integer) }
  def inactive_minute_limit
    return 240 if user&.admin? || user&.donator?

    45
  end

  sig { returns(T.nilable(String)) }
  def custom_whitelist_content
    WhitelistTf.find_by(tf_whitelist_id: custom_whitelist_id).try(:content)
  end

  def calculate_duration
    self.duration = (ends_at.to_i - starts_at.to_i)
  end

  def generate_logsecret
    self.logsecret ||= rand(2**128).to_s
  end

  sig { params(steam_uid: T.any(String, Integer)).returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.played_in(steam_uid)
    ordered.joins(:reservation_players)
      .where(reservation_players: { steam_uid: steam_uid })
      .where(starts_at: (31.days.ago..))
      .where(ended: true)
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
    attributes.slice("server_id", "password", "rcon", "tv_password", "server_config_id", "whitelist_id", "custom_whitelist_id", "first_map", "enable_demos_tf")
  end

  def template_attributes
    attributes.slice(*self.class.template_attribute_names)
  end

  def self.template_attribute_names
    %w[server_config_id whitelist_id custom_whitelist_id first_map]
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_binding
    binding
  end
  # rubocop:enable Naming/AccessorMethodName

  sig { returns(T::Boolean) }
  def times_entered?
    !!(starts_at && ends_at)
  end

  sig { params(status: String).returns(ReservationStatus) }
  def status_update(status)
    reservation_statuses.create!(status: status)
  end

  sig { returns(T::Boolean) }
  def lobby?
    Rails.cache.fetch("reservation_#{id}_lobby") do
      tags = server&.rcon_exec("sv_tags").to_s
      tags.include?("TF2Center") || tags.include?("TF2Stadium") || tags.include?("TF2Pickup")
    end
  end

  sig { returns(String) }
  def api_keys_rcon_contents
    contents = "logstf_apikey \"#{user&.logs_tf_api_key.presence || Rails.application.credentials.dig(:logs_tf, :api_key)}\"; sm_web_rcon_url \"#{SITE_URL}/reservations/#{id}/rcon\""
    if enable_demos_tf?
      contents + "; sm_demostf_apikey \"#{user&.demos_tf_api_key.presence || Rails.application.credentials.dig(:demos_tf, :api_key)}\""
    else
      contents
    end
  end

  sig { returns(String) }
  def status
    return "Ended" if past?

    status_messages = reservation_statuses.pluck(:status)
    return "Ended" if status_messages.include?("Finished zipping logs and demos")

    return "Ending" if status_messages.include?("Ending")

    return "SDR Ready" if server&.sdr? && sdr_ip.present?
    return "Ready" if server_statistics.any? && !server&.sdr?
    return "Ready" if status_messages.grep(/\AServer finished loading map/).any? && !server&.sdr?

    return "Server updating, please be patient" if status_messages.grep(/\AServer outdated/).any?

    return "Starting" if status_messages.include?("Starting")

    return "Waiting to start" if status_messages.include?("Waiting to start")

    "Unknown"
  end

  sig { returns(T::Boolean) }
  def poor_rcon_password?
    rcon.nil? || rcon.to_s.size < 8
  end

  sig { returns(T::Boolean) }
  def locked?
    locked_at.present?
  end

  sig { returns(String) }
  def generate_rcon_password!
    self.rcon = FriendlyPasswordGenerator.generate
  end

  sig { returns(T::Boolean) }
  def lock!
    lock_password = FriendlyPasswordGenerator.generate

    update_columns(
      locked_at: Time.current,
      original_password: original_password || password
    )

    update_columns(password: lock_password)

    server&.rcon_exec "sv_password \"#{lock_password}\""
    server&.add_motd(reload)

    true
  end

  sig { returns(T::Boolean) }
  def unlock!
    return false unless locked?

    restore_password = original_password || FriendlyPasswordGenerator.generate

    update_columns(
      locked_at: nil,
      password: restore_password,
      original_password: nil
    )

    server&.rcon_exec "sv_password #{restore_password}; removeid 1"
    server&.add_motd(reload)

    true
  end

  sig { returns(T::Hash[Symbol, T.any(Integer, String)]) }
  def unban_all!
    listid_result = server&.rcon_exec("listid")&.to_s

    if listid_result && (listid_result.match?(/(\d+)\s+entr(?:y|ies)/) || listid_result.match?(/ID filter list: empty/i))
      if listid_result.match?(/ID filter list: empty/i)
        { count: 0, message: "No players are currently banned" }
      else
        entries_count = listid_result.match(/(\d+)\s+entr(?:y|ies)/)[1].to_i
        unban_commands = Array.new(entries_count) { "removeid 1" }
        server&.rcon_exec(unban_commands.join("; "))
        { count: entries_count, message: "Unbanned #{entries_count} player#{'s' if entries_count != 1}" }
      end
    else
      { count: nil, message: "Unable to check ban list" }
    end
  end

  sig { returns(String) }
  def whitelist_ip
    return T.must(user&.current_sign_in_ip) if user&.current_sign_in_ip && IPAddr.new(user&.current_sign_in_ip).ipv4?

    return T.must(user&.reservation_players&.last&.ip) if user&.reservation_players&.last&.ip

    "direct.#{SITE_HOST}"
  end

  sig { returns(String) }
  def logs_tf_url
    "http://logs.tf/search/log?s=#{SITE_HOST}+%23#{id}"
  end

  def save_sdr_info(server_info)
    return if server_info.ip.nil?

    previous_server_sdr_ip = server&.last_sdr_ip
    previous_server_sdr_port = server&.last_sdr_port&.to_i

    return if previous_server_sdr_ip == server_info.ip && previous_server_sdr_port == server_info&.port&.to_i && sdr_ip == server_info.ip && sdr_port&.to_i == server_info.port&.to_i

    update_columns(
      sdr_ip: server_info.ip,
      sdr_port: server_info.port,
      sdr_tv_port: server_info.port.to_i + 1
    )

    server&.update_columns(
      last_sdr_ip: server_info.ip,
      last_sdr_port: server_info.port,
      last_sdr_tv_port: server_info.port.to_i + 1
    )

    broadcast_connect_info
    status_update("SDR ready, server available at #{server_info.ip}:#{server_info.port}")

    server&.reload&.add_sourcemod_servers(self)
    server&.rcon_exec("sm plugins reload serverhop")
  end

  def broadcast_connect_info
    broadcast_replace_to self, target: "reservation_connect_info_#{id}", partial: "reservations/connect_info", locals: { reservation: self }
    broadcast_replace_to self, target: "reservation_sdr_connect_info_#{id}", partial: "reservations/sdr_connect_info", locals: { reservation: self }
    broadcast_replace_to self, target: "reservation_stv_connect_info_#{id}", partial: "reservations/stv_connect_info", locals: { reservation: self }
    broadcast_replace_to self, target: "reservation_actions_#{id}", partial: "reservations/actions", locals: { reservation: self }
  end

  sig { returns(T::Boolean) }
  def zipfile_available?
    local_zipfile_available? || zipfile.attached?
  end

  sig { returns(T::Boolean) }
  def local_zipfile_available?
    !!(younger_than_cleanup_age? && local_zipfile_path && File.exist?(local_zipfile_path))
  end

  sig { returns(T.nilable(Pathname)) }
  def local_zipfile_path
    Rails.root.join("public", "uploads", zipfile_name)
  end

  private

  sig { returns(ReservationManager) }
  def reservation_manager
    ReservationManager.new(self)
  end

  sig { returns(T.nilable(ReservationStatus)) }
  def generate_initial_status
    status_update("Waiting to start") if future?
  end

  sig { void }
  def update_user_total_seconds_counter
    return unless T.must(user).has_attribute?(:total_reservation_seconds)

    total_seconds = T.must(user).reservations.sum(:duration)
    T.must(user).update_column(:total_reservation_seconds, total_seconds)
  end
end
