# frozen_string_literal: true

class Server < ActiveRecord::Base
  include ApplicationHelper

  has_many :group_servers
  has_many :groups, through: :group_servers
  has_many :reservations
  has_many :current_reservations, -> { where('reservations.starts_at <= ? AND reservations.ends_at >=?', Time.current, Time.current) }, class_name: 'Reservation'
  has_many :ratings, through: :reservations
  has_many :recent_server_statistics, -> { where('server_statistics.created_at >= ?', 2.minutes.ago).order('server_statistics.id DESC') }, class_name: 'ServerStatistic'
  has_many :server_statistics
  belongs_to :location

  validates_presence_of %i[name ip port path rcon]

  geocoded_by :host_to_ip
  before_save :geocode, if: :ip_changed?

  delegate :flag, to: :location, prefix: true, allow_nil: true

  def self.reservable_by_user(user)
    where(id: ids_reservable_by_user(user))
  end

  def self.ids_reservable_by_user(user)
    without_group.pluck(:id) + member_of_groups(user.groups).pluck(:id)
  end

  def self.ordered
    order('servers.position ASC, servers.name ASC')
  end

  def self.without_group
    if with_group.exists?
      where('servers.id NOT IN (?)', with_group.pluck(:id))
    else
      all
    end
  end

  def self.with_group
    joins(:groups)
  end

  def self.active
    where('servers.active = ?', true)
  end

  def self.member_of_groups(groups)
    with_group
      .where(groups: { id: groups.pluck(:id) })
      .group('servers.id')
  end

  def self.for_donators
    Group.donator_group.servers
  end

  def self.outdated(latest_version = nil)
    latest_version ||= self.latest_version

    where('last_known_version is not null and last_known_version < ?', latest_version)
  end

  def self.updated(latest_version = nil)
    latest_version ||= self.latest_version

    where('last_known_version is null or last_known_version = ?', latest_version)
  end

  def self.updating
    where('update_status = ?', 'Updating')
  end

  def public_ip
    return last_sdr_ip if sdr?

    ip
  end

  def public_port
    return last_sdr_port if sdr?

    port
  end

  def public_tv_port
    return last_sdr_tv_port if sdr?

    tv_port
  end

  def server_connect_string(password)
    connect_string(public_ip, public_port, password)
  end

  def stv_connect_string(tv_password)
    connect_string(public_ip, public_tv_port, tv_password)
  end

  def server_connect_url(password)
    steam_connect_url(public_port, password)
  end

  def stv_connect_url(password)
    steam_connect_url(public_tv_port, password)
  end

  def update_configuration(reservation)
    reservation.status_update('Sending reservation config files')
    ['reservation.cfg', 'ctf_turbine.cfg'].each do |config_file|
      config_body = generate_config_file(reservation, config_file)
      write_configuration(server_config_file(config_file), config_body)
    end
    add_motd(reservation)
    write_custom_whitelist(reservation) if reservation.custom_whitelist_id.present?
    reservation.status_update('Finished sending reservation config files')
  end

  def enable_plugins
    write_configuration(sourcemod_file, sourcemod_body)
  end

  def add_sourcemod_admin(user)
    write_configuration(sourcemod_admin_file, sourcemod_admin_body(user))
  end

  def add_sourcemod_servers(reservation)
    write_configuration(sourcemod_servers_file, sourcemod_servers_body(reservation))
  end

  def add_motd(reservation)
    write_configuration(motd_file, motd_body(reservation))
  end

  def disable_plugins
    delete_from_server([sourcemod_file, sourcemod_admin_file])
  end

  def sourcemod_file
    "#{tf_dir}/addons/metamod/sourcemod.vdf"
  end

  def sourcemod_body
    <<-VDF
    "Metamod Plugin"
    {
      "alias"		"sourcemod"
      "file"		"addons/sourcemod/bin/sourcemod_mm"
    }
    VDF
  end

  def motd_body(reservation)
    "#{SITE_URL}/reservations/#{reservation.id}/motd?password=#{URI.encode_uri_component(reservation.password)}"
  end

  def sourcemod_admin_file
    "#{tf_dir}/addons/sourcemod/configs/admins_simple.ini"
  end

  def sourcemod_servers_file
    "#{tf_dir}/addons/sourcemod/configs/serverhop.cfg"
  end

  def sourcemod_admin_body(user)
    uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(user.uid.to_i)
    flags = sdr? ? 'abcdefghijkln' : 'z'
    <<-INI
    "#{uid3}" "99:#{flags}"
    INI
  end

  def sourcemod_servers_body(reservation)
    <<-CFG
    "Servers"
    {
            "Direct connection"
            {
                    "address"               "#{reservation.server.ip}"
                    "port"          "#{reservation.server.port}"
            }
            "SDR (Valve VPN)"
            {
                    "address"               "#{reservation.connect_sdr_ip}"
                    "port"          "#{reservation.connect_sdr_port}"
            }
    }
    CFG
  end

  def write_custom_whitelist(reservation)
    write_configuration(server_config_file("custom_whitelist_#{reservation.custom_whitelist_id}.txt"), reservation.custom_whitelist_content)
  end

  def generate_config_file(object, config_file)
    template         = File.read(Rails.root.join("lib/#{config_file}.erb"))
    renderer         = ERB.new(template)
    renderer.result(object.get_binding)
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_binding
    binding
  end
  # rubocop:enable Naming/AccessorMethodName

  def process_id
    @process_id ||= begin
      pid = find_process_id.to_i
      pid.positive? && pid
    end
  end

  def tf_dir
    File.join(path, 'tf')
  end

  def current_rcon
    if current_reservation&.provisioned?
      current_reservation.rcon
    else
      rcon
    end
  end

  def current_reservation
    current_reservations.first
  end

  def inactive_minutes
    current_reservation&.inactive_minute_counter || 0
  end

  def occupied?
    if number_of_players
      number_of_players.positive?
    else
      true
    end
  end

  def start_reservation(reservation)
    reservation.enable_mitigations if supports_mitigations?

    update_configuration(reservation)
    if reservation.enable_plugins? || reservation.enable_demos_tf? || au_system?
      reservation.status_update('Enabling plugins')
      enable_plugins
      add_sourcemod_admin(reservation.user)
      add_sourcemod_servers(reservation)
      reservation.status_update('Enabled plugins')
      if reservation.enable_demos_tf? || au_system?
        reservation.status_update('Enabling demos.tf')
        enable_demos_tf
        reservation.status_update('Enabled demos.tf')
      end
    end
    ensure_map_on_server(reservation)
    if reservation.server.outdated?
      reservation.status_update('Server outdated, restarting server to update')
      clear_sdr_info!
      restart
      reservation.status_update('Restarted server, waiting to boot')
    else
      reservation.status_update('Attempting fast start')
      if rcon_exec("removeip 1; removeip 1; removeip 1; sv_logsecret #{reservation.logsecret}; logaddress_add direct.#{SITE_HOST}:40001", allow_blocked: true)
        first_map = first_map.presence || 'ctf_turbine'
        rcon_exec("changelevel #{first_map}; exec reservation.cfg")
        reservation.status_update('Fast start attempted, waiting to boot')
      else
        reservation.status_update('Fast start failed, starting server normally')
        clear_sdr_info!
        restart
        reservation.status_update('Restarted server, waiting to boot')
      end
    end
  end

  def ensure_map_on_server(reservation)
    return if reservation.first_map.blank? || map_present?(reservation.first_map)

    reservation.status_update("Map #{reservation.first_map} not on the server, uploading")

    upload_map_to_server(reservation)
  end

  def map_present?(map_name)
    file_present?("#{tf_dir}/maps/#{map_name}.bsp")
  end

  def upload_map_to_server(reservation)
    tempfile = Down.download("https://fastdl.serveme.tf/maps/#{reservation.first_map}.bsp")
    copy_to_server([tempfile.path], "#{tf_dir}/maps/#{reservation.first_map}.bsp")
    reservation.status_update("Uploaded map #{reservation.first_map} to server")
  end

  def update_reservation(reservation)
    update_configuration(reservation)
  end

  def end_reservation(reservation)
    reservation.reload
    return if reservation.ended?

    remove_configuration
    download_stac_logs(reservation)
    disable_plugins
    disable_demos_tf
    rcon_exec("sv_logflush 1; tv_stoprecord; kickall Reservation ended, every player can download the STV demo at https:/​/#{SITE_HOST}")
    sleep 1 # Give server a second to finish the STV demo and write the log
    zip_demos_and_logs(reservation)
    copy_logs(reservation)
    remove_logs_and_demos
    reservation.status_update('Restarting server')
    rcon_disconnect
    clear_sdr_info!
    restart
    reservation.status_update('Restarted server')
  end

  def download_stac_logs(reservation)
    StacLogsDownloaderWorker.perform_async(reservation.id)
  end

  def enable_demos_tf
    demos_tf_file = Rails.root.join('doc', 'demostf.smx').to_s
    copy_to_server([demos_tf_file], "#{tf_dir}/addons/sourcemod/plugins")
  end

  def disable_demos_tf
    delete_from_server(["#{tf_dir}/addons/sourcemod/plugins/demostf.smx"])
  end

  def zip_demos_and_logs(reservation)
    ZipFileCreator.create(reservation, logs_and_demos)
  end

  def copy_logs(reservation)
    LogCopier.copy(reservation, self)
  end

  def condenser
    @condenser ||= SteamCondenser::Servers::SourceServer.new(ip, port.to_i)
  end

  def rcon_auth(rcon = current_rcon)
    @rcon_auth ||= condenser.rcon_auth(rcon)
  rescue NoMethodError # Empty rcon reply, typically due to rcon ban
    nil
  end

  def rcon_say(message)
    rcon_exec("say #{message}")
  end

  def rcon_exec(command, allow_blocked: false)
    return nil if blocked_command?(command) && !allow_blocked

    condenser.rcon_exec(command) if rcon_auth
  rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout, SteamCondenser::Error::RCONNoAuth, SteamCondenser::Error::RCONBan => e
    Rails.logger.error "Couldn't deliver command to server #{id} - #{name}, command: #{command}, exception: #{e}"
    nil
  end

  def blocked_command?(command)
    blocked_commands.any? do |c|
      command.downcase.include?(c)
    end
  end

  def rcon_disconnect
    condenser.disconnect
  rescue StandardError => e
    Rails.logger.error "Couldn't disconnect RCON of server #{id} - #{name}, exception: #{e}"
  ensure
    @condenser = nil
  end

  def version
    @version ||= /Network\ PatchVersion:\s+(\d+)/ =~ rcon_exec('version') && Regexp.last_match(1).to_i
  end

  def outdated?
    version != Server.latest_version
  end

  def self.latest_version
    Rails.cache.fetch('latest_server_version', expires_in: 5.minutes) do
      fetch_latest_version
    end
  rescue Net::ReadTimeout, Faraday::TimeoutError
    nil
  end

  def self.fetch_latest_version
    return 100_000_000 if Rails.env.test?

    response = Faraday.new(url: 'http://api.steampowered.com').get('ISteamApps/UpToDateCheck/v1?appid=440&version=0') do |req|
      req.options.timeout = 5
      req.options.open_timeout = 2
    end
    return unless response.success?

    json = JSON.parse(response.body)
    json['response']['required_version'].to_i
  end

  def number_of_players
    @number_of_players ||= server_info.number_of_players
  rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout
    nil
  end

  def server_info
    @server_info ||= ServerInfo.new(self)
  end

  def tv_port
    self[:tv_port]&.to_i || (port.to_i + 5)
  end

  def supports_mitigations?
    false
  end

  def connect_string(ip, port, password)
    "connect #{ip}:#{port}; password \"#{password}\""
  end

  def steam_connect_url(port, password)
    "steam://connect/#{hostname_to_ip}:#{port}/#{CGI.escape(password)}"
  end

  def hostname_to_ip
    @hostname_to_ip ||=
      begin
        Resolv.getaddress(public_ip)
      rescue Resolv::ResolvError
        public_ip
      end
  end

  def clear_sdr_info!
    persisted? && update_columns(last_sdr_ip: nil, last_sdr_port: nil, last_sdr_tv_port: nil)
  end

  def save_version_info(server_info)
    return unless server_info&.version.present?

    if server_info.version < self.class.latest_version
      Rails.logger.warn("Server #{name} was updating since #{I18n.l(update_started_at, format: :short)} but is now back online with old version #{server_info.version} instead of latest #{self.class.latest_version}") if update_status == 'Updating'

      update(update_status: 'Outdated', last_known_version: server_info.version)
    else
      Rails.logger.info("Server #{name} was updating since #{I18n.l(update_started_at, format: :short)} from version #{last_known_version} and is now back online with latest version #{server_info.version}") if %w[Updating Outdated].include?(update_status)

      update(update_status: 'Updated', last_known_version: server_info.version)
    end
  end

  private

  def logs_and_demos
    @logs_and_demos ||= logs + demos
  end

  def log_match
    File.join(tf_dir, 'logs', '*.log')
  end

  def stac_log_match
    File.join(tf_dir, 'addons', 'sourcemod', 'logs', 'stac', '*.log')
  end

  def demo_match
    File.join(tf_dir, '*.dem')
  end

  def server_config_file(config_file)
    "#{tf_dir}/cfg/#{config_file}"
  end

  def configuration_files
    [reservation_config_file, initial_map_config_file, banned_user_file, banned_ip_file, motd_file]
  end

  def reservation_config_file
    server_config_file('reservation.cfg')
  end

  def initial_map_config_file
    server_config_file('ctf_turbine.cfg')
  end

  def banned_user_file
    server_config_file('banned_user.cfg')
  end

  def banned_ip_file
    server_config_file('banned_ip.cfg')
  end

  def motd_file
    "#{tf_dir}/motd.txt"
  end

  def host_to_ip
    Resolv.getaddress(ip) unless Rails.env.test?
  end

  def blocked_commands
    @blocked_commands ||= %w[logaddress rcon_password sv_downloadurl]
  end
end
