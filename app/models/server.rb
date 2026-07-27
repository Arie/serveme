# typed: true
# frozen_string_literal: true

class Server < ActiveRecord::Base
  extend T::Sig
  include ApplicationHelper

  has_many :group_servers
  has_many :groups, through: :group_servers
  has_many :reservations
  has_many :current_reservations, -> { where(starts_at: ..Time.current).where(ends_at: Time.current..) }, class_name: "Reservation"
  has_many :ratings, through: :reservations
  has_many :recent_server_statistics, -> { where(created_at: 2.minutes.ago..).order(id: :desc) }, class_name: "ServerStatistic"
  has_many :server_statistics
  belongs_to :location

  validates_presence_of :name, :ip, :port, :path, :rcon
  validates :port, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 65535 }

  geocoded_by :host_to_ip do |server|
    # Check for override first
    override = server.geocoding_override_for(server.ip)
    if override && override["latitude"] && override["longitude"]
      [ override["latitude"], override["longitude"] ]
    else
      # Fall through to actual geocoder lookup
      result = Geocoder.search(server.host_to_ip)&.first
      [ result.latitude, result.longitude ] if result&.latitude && result&.longitude
    end
  end

  before_save :geocode, if: :should_geocode?
  after_save :update_resolved_ip, if: :saved_change_to_ip?

  delegate :flag, to: :location, prefix: true, allow_nil: true

  sig { returns(String) }
  def detailed_location
    return "Unknown" unless ip.present?

    Rails.cache.fetch("server_detailed_location_v5_#{id}", expires_in: 1.week) do
      override = geocoding_override_for(T.must(ip))
      override ? detailed_location_from_override(override) : detailed_location_from_geocoder
    end
  rescue => e
    Rails.logger.error "Geocoding error for server #{id}: #{e.message}"
    location&.name || "Unknown"
  end

  sig { params(ip_address: String).returns(T.nilable(T::Hash[String, T.untyped])) }
  def geocoding_override_for(ip_address)
    @geocoding_overrides ||= load_geocoding_overrides

    # Check by IP first, then by hostname
    @geocoding_overrides[ip_address] || @geocoding_overrides[ip]
  end

  scope :reservable_by_user, ->(user) {
    not_cloud.where(id: ids_reservable_by_user(user))
  }

  sig { params(user: User).returns(T::Array[Integer]) }
  def self.ids_reservable_by_user(user)
    without_group.pluck(:id) + member_of_groups(user.groups).pluck(:id)
  end

  scope :ordered, -> { order(:position, :name) }

  scope :without_group, -> { where.not(id: with_group.select(:id)) }

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.with_group
    joins(:groups)
  end

  scope :active, -> { where(active: true) }

  scope :not_cloud, -> { where.not(type: "CloudServer") }

  sig { params(groups: T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)).returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.member_of_groups(groups)
    with_group
      .where(groups: { id: groups.pluck(:id) })
      .group(:id)
  end

  scope :for_donators, -> {
    joins(:group_servers).where(group_servers: { group_id: Group::DONATOR_GROUP.id })
  }

  scope :outdated, ->(latest_version = nil) {
    latest_version ||= self.latest_version
    # Without a known version the range below degrades to `1=1` and matches every
    # server, which would have ServerUpdateWorker restart the whole fleet.
    next none if latest_version.blank?

    where.not(last_known_version: nil)
      .where(last_known_version: ...latest_version)
      .where.not(id: team_comtress_servers.select(:id))
      .where.not(type: "CloudServer")
  }

  sig { returns(ActiveRecord::Relation) }
  def self.team_comtress_servers
    joins(:groups).where(groups: { id: Group.team_comtress_group.id }).group(:id)
  end

  scope :updated, ->(latest_version = nil) {
    latest_version ||= self.latest_version
    tc_server_ids = team_comtress_servers.pluck(:id)

    where(last_known_version: [ nil, latest_version ])
      .or(where(id: tc_server_ids))
  }

  scope :updating, -> { where(update_status: "Updating") }

  sig { returns(T.nilable(String)) }
  def public_ip
    return last_sdr_ip if sdr?

    ip
  end

  sig { returns(T.nilable(String)) }
  def host_hostname
    ip
  end

  sig { returns(T.nilable(String)) }
  def public_numeric_ip
    return public_ip if sdr?

    resolved_ip.presence || hostname_to_ip
  end

  sig { returns(T.nilable(T.any(Integer, String))) }
  def public_port
    return last_sdr_port if sdr?

    port
  end

  sig { returns(T.nilable(T.any(Integer, String))) }
  def public_tv_port
    return last_sdr_tv_port if sdr?

    tv_port
  end

  sig { params(password: String).returns(T.nilable(String)) }
  def server_connect_string(password)
    connect_string(public_ip, public_port, password)
  end

  sig { params(tv_password: String).returns(T.nilable(String)) }
  def stv_connect_string(tv_password)
    connect_string(public_ip, public_tv_port, tv_password)
  end

  sig { params(password: String).returns(T.nilable(String)) }
  def server_connect_url(password)
    steam_connect_url(public_numeric_ip, public_port, password)
  end

  sig { params(password: String).returns(T.nilable(String)) }
  def stv_connect_url(password)
    steam_connect_url(public_numeric_ip, public_tv_port, password)
  end

  sig { params(reservation: Reservation).returns(ReservationStatus) }
  def update_configuration(reservation)
    config_file_writer.update_configuration(reservation)
  end

  sig { params(reservation: Reservation).returns(T.untyped) }
  def handle_rgl_base_cfg(reservation)
    config_file_writer.handle_rgl_base_cfg(reservation)
  end

  sig { returns(T.untyped) }
  def restore_rgl_base_cfg
    config_file_writer.restore_rgl_base_cfg
  end

  sig { returns(T.untyped) }
  def enable_plugins
    config_file_writer.enable_plugins
  end

  sig { params(user: User).returns(T.untyped) }
  def add_sourcemod_admin(user)
    config_file_writer.add_sourcemod_admin(user)
  end

  sig { params(reservation: Reservation).returns(T.untyped) }
  def add_motd(reservation)
    config_file_writer.add_motd(reservation)
  end

  sig { returns(T.untyped) }
  def disable_plugins
    config_file_writer.disable_plugins
  end

  sig { params(reservation: Reservation).returns(T.untyped) }
  def write_custom_whitelist(reservation)
    config_file_writer.write_custom_whitelist(reservation)
  end

  sig { returns(T.nilable(Integer)) }
  def process_id
    @process_id ||= begin
      pid = find_process_id.to_i
      pid if pid.positive?
    end
  end

  sig { returns(String) }
  def tf_dir
    @tf_dir ||= begin
      game_dir = team_comtress_server? ? "tc2" : "tf"
      File.join(path, game_dir)
    end
  end

  sig { returns(T.nilable(String)) }
  def current_rcon
    if current_reservation&.provisioned?
      T.must(current_reservation).rcon
    else
      rcon
    end
  end

  sig { returns(T.nilable(Reservation)) }
  def current_reservation
    current_reservations.first
  end

  sig { returns(Integer) }
  def inactive_minutes
    current_reservation&.inactive_minute_counter || 0
  end

  sig { returns(T::Boolean) }
  def occupied?
    if number_of_players
      T.must(number_of_players).positive?
    else
      true
    end
  end

  sig { params(reservation: Reservation).void }
  def start_reservation(reservation)
    reservation_lifecycle.start_reservation(reservation)
  end

  sig { params(reservation: Reservation).void }
  def update_reservation(reservation)
    reservation_lifecycle.update_reservation(reservation)
  end

  sig { params(reservation: Reservation).void }
  def end_reservation(reservation)
    reservation_lifecycle.end_reservation(reservation)
  end

  sig { returns(T.untyped) }
  def condenser
    rcon_gateway.condenser
  end

  sig { params(rcon: T.nilable(String)).returns(T.nilable(T::Boolean)) }
  def rcon_auth(rcon = current_rcon)
    rcon_gateway.auth(rcon)
  end

  sig { params(message: String).returns(T::Array[T.nilable(String)]) }
  def rcon_say(message)
    rcon_gateway.say(message)
  end

  sig { params(command: String, allow_blocked: T::Boolean).returns(T.nilable(String)) }
  def rcon_exec(command, allow_blocked: false)
    rcon_gateway.exec(command, allow_blocked: allow_blocked)
  end

  sig { void }
  def rcon_disconnect
    rcon_gateway.disconnect
  end

  sig { returns(T.nilable(Integer)) }
  def version
    version_checker.current
  end

  sig { returns(T::Boolean) }
  def outdated?
    version_checker.outdated?
  end

  sig { params(reservation: Reservation).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
  def provision_estimate(reservation)
    ServerReservationEstimator.new(reservation).provision_estimate
  end

  sig { params(reservation: Reservation).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
  def end_estimate(reservation)
    ServerReservationEstimator.new(reservation).end_estimate
  end

  sig { returns(T::Boolean) }
  def team_comtress_server?
    return @team_comtress_server if defined?(@team_comtress_server)

    @team_comtress_server = groups.any? { |g| g.id == Group.team_comtress_group.id }
  end

  sig { returns(T.nilable(Integer)) }
  def self.latest_version
    ServerVersionChecker.latest_version
  end

  sig { returns(T.nilable(Integer)) }
  def self.fetch_latest_version
    ServerVersionChecker.fetch_latest_version
  end

  sig { returns(T.nilable(Integer)) }
  def number_of_players
    @number_of_players ||= server_info.number_of_players
  rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout
    nil
  end

  sig { returns(ServerInfo) }
  def server_info
    @server_info ||= ServerInfo.new(self)
  end

  sig { returns(Integer) }
  def tv_port
    self[:tv_port]&.to_i || (port.to_i + 5)
  end

  sig { returns(T::Boolean) }
  def supports_mitigations?
    false
  end

  sig { params(command: String, log_stderr: T::Boolean).returns(String) }
  def mitigation_ssh_exec(command, log_stderr: false) # rubocop:disable Lint/UnusedMethodArgument
    raise NotImplementedError, "#{self.class} does not support mitigations"
  end

  sig { params(ip: T.nilable(String), port: T.nilable(T.any(Integer, String)), password: T.nilable(String)).returns(T.nilable(String)) }
  def connect_string(ip, port, password)
    return nil if ip.nil? || port.nil?

    "connect #{ip}:#{port}; password \"#{password}\""
  end

  # Valve's steam://connect handler rejects hostnames, so join urls must always
  # carry a numeric address even though connect strings show the friendly one.
  sig { params(ip: T.nilable(String), port: T.nilable(T.any(Integer, String)), password: T.nilable(String)).returns(T.nilable(String)) }
  def steam_connect_url(ip, port, password)
    return nil if ip.nil? || port.nil?

    "steam://connect/#{ip}:#{port}/#{CGI.escape(password.to_s)}"
  end

  sig { returns(T.nilable(String)) }
  def hostname_to_ip
    @hostname_to_ip ||=
      begin
        Resolv.getaddress(T.must(public_ip))
      rescue Resolv::ResolvError
        public_ip
      end
  end

  sig { void }
  def clear_sdr_info!
    persisted? && update_columns(last_sdr_ip: nil, last_sdr_port: nil, last_sdr_tv_port: nil)
  end

  sig { params(server_info: T.nilable(ServerInfo)).void }
  def save_version_info(server_info)
    version = server_info&.version
    latest_version = self.class.latest_version
    return if version.nil? || latest_version.nil?

    # Team Comtress servers run a different version and should not be marked as outdated
    if team_comtress_server?
      update(last_known_version: version) if last_known_version != version
      return
    end

    if version < latest_version
      Rails.logger.warn("Server #{name} was updating since #{update_started_at ? I18n.l(update_started_at, format: :short) : 'unknown'} but is now back online with old version #{version} instead of latest #{latest_version}") if update_status == "Updating"

      update(update_status: "Outdated", last_known_version: version)
    else
      Rails.logger.info("Server #{name} was updating since #{update_started_at ? I18n.l(update_started_at, format: :short) : 'unknown'} from version #{last_known_version} and is now back online with latest version #{version}") if %w[Updating Outdated].include?(update_status)

      update(update_status: "Updated", last_known_version: version)
    end
  end

  def write_configuration(_filename, _contents)
    raise "not implemented"
  end

  def remove_configuration
    raise "not implemented"
  end

  def find_process_id
    raise "not implemented"
  end

  def restart
    raise "not implemented"
  end

  def ensure_directories(_paths)
    raise "not implemented"
  end

  def copy_to_server(_files, _destination)
    raise "not implemented"
  end

  def delete_from_server(_files)
    raise "not implemented"
  end

  def logs
    raise "not implemented"
  end

  def demos
    raise "not implemented"
  end

  def remove_logs_and_demos
    raise "not implemented"
  end

  def file_present?(_file)
    raise "not implemented"
  end

  sig { params(_reservation: Reservation).void }
  def move_files_to_temp_directory(_reservation)
    raise "not implemented"
  end

  sig { params(_reservation: Reservation).returns(String) }
  def temp_directory_for_reservation(_reservation)
    raise "not implemented"
  end

  sig { returns(T::Boolean) }
  def uses_async_cleanup?
    false
  end

  sig { returns(T::Boolean) }
  def cloud?
    false
  end

  sig { returns(T::Boolean) }
  def local?
    false
  end

  sig { returns(T::Boolean) }
  def ssh_based?
    false
  end

  # Only CloudServer pre-writes the first map so its container boots into it;
  # other types set it via changelevel during start_reservation.
  sig { params(reservation: Reservation).returns(T.nilable(T::Boolean)) }
  def write_first_map(reservation) # rubocop:disable Lint/UnusedMethodArgument
    nil
  end

  sig { returns(T.nilable(String)) }
  def host_to_ip
    return if Rails.env == "test"

    cache_key = "dns:#{ip}"
    resolved = begin
      Resolv.getaddress(T.must(ip))
    rescue Resolv::ResolvError
      nil
    end

    if resolved
      Rails.cache.write(cache_key, resolved, expires_in: 1.day)
      resolved
    else
      Rails.cache.read(cache_key)
    end
  end

  sig { returns(T::Boolean) }
  def should_geocode?
    ip_changed? && (latitude.blank? || longitude.blank?)
  end

  sig { returns(T::Array[String]) }
  def logs_and_demos
    @logs_and_demos ||= logs + demos
  end

  private

  sig { returns(ServerVersionChecker) }
  def version_checker
    @version_checker ||= T.let(ServerVersionChecker.new(self), T.nilable(ServerVersionChecker))
  end

  sig { returns(ServerRconGateway) }
  def rcon_gateway
    @rcon_gateway ||= T.let(ServerRconGateway.new(self), T.nilable(ServerRconGateway))
  end

  sig { returns(ServerConfigFileWriter) }
  def config_file_writer
    @config_file_writer ||= T.let(ServerConfigFileWriter.new(self), T.nilable(ServerConfigFileWriter))
  end

  sig { returns(ServerReservationLifecycle) }
  def reservation_lifecycle
    @reservation_lifecycle ||= T.let(ServerReservationLifecycle.new(self), T.nilable(ServerReservationLifecycle))
  end

  sig { params(override: T::Hash[String, T.untyped]).returns(String) }
  def detailed_location_from_override(override)
    format_location(override["city"], override["state"], override["country"] || location&.name)
  end

  sig { returns(String) }
  def detailed_location_from_geocoder
    result = Geocoder.search(ip).first
    return location&.name || "Unknown" unless result && result.city.present?

    country = location&.name || result.country
    region = result.state
    region = result.data.dig("subdivisions", 0, "iso_code") || region if country == "USA" && region.present?
    format_location(result.city, region, country)
  end

  sig { params(city: T.untyped, region: T.untyped, country: T.untyped).returns(String) }
  def format_location(city, region, country)
    return "#{city}, #{region}" if country == "USA" && region.present?

    "#{city}, #{country}"
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def load_geocoding_overrides
    override_file = Rails.root.join("config", "geocoding_overrides.yml")
    return {} unless File.exist?(override_file)

    config = YAML.load_file(override_file)
    config["overrides"] || {}
  rescue => e
    Rails.logger.error "Error loading geocoding overrides: #{e.message}"
    {}
  end

  sig { returns(String) }
  def log_match
    File.join(tf_dir, "logs", "*.log")
  end

  sig { returns(String) }
  def stac_log_match
    File.join(tf_dir, "addons", "sourcemod", "logs", "stac", "*.log")
  end

  sig { returns(String) }
  def demo_match
    File.join(tf_dir, "*.dem")
  end

  sig { params(config_file: String).returns(String) }
  def server_config_file(config_file)
    "#{tf_dir}/cfg/#{config_file}"
  end

  sig { returns(T::Array[String]) }
  def configuration_files
    [ reservation_config_file, initial_map_config_file, banned_user_file, banned_ip_file, motd_file ]
  end

  sig { returns(String) }
  def reservation_config_file
    server_config_file("reservation.cfg")
  end

  sig { returns(String) }
  def initial_map_config_file
    server_config_file("ctf_turbine.cfg")
  end

  sig { returns(String) }
  def banned_user_file
    server_config_file("banned_user.cfg")
  end

  sig { returns(String) }
  def banned_ip_file
    server_config_file("banned_ip.cfg")
  end

  sig { returns(String) }
  def motd_file
    "#{tf_dir}/motd.txt"
  end

  sig { void }
  def update_resolved_ip
    return if ip.blank?

    PopulateResolvedIpsService.new.update_server(self)
  end
end
