# frozen_string_literal: true

class Server < ActiveRecord::Base
  has_many :group_servers
  has_many :groups, through: :group_servers
  has_many :reservations
  has_many :current_reservations, -> { where('reservations.starts_at <= ? AND reservations.ends_at >=?', Time.current, Time.current) }, class_name: 'Reservation'
  has_many :ratings, through: :reservations
  has_many :recent_server_statistics, -> { where('server_statistics.created_at >= ?', 2.minutes.ago).order('server_statistics.id DESC') }, class_name: 'ServerStatistic'
  has_many :server_statistics
  belongs_to :location

  validates_presence_of :name
  validates_presence_of :ip
  validates_presence_of :port
  validates_presence_of :path

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
    steam_connect_url(public_ip, public_port, password)
  end

  def stv_connect_url(password)
    steam_connect_url(public_ip, public_tv_port, password)
  end

  def update_configuration(reservation)
    reservation.status_update('Sending reservation config files')
    ['reservation.cfg', 'ctf_turbine.cfg'].each do |config_file|
      config_body = generate_config_file(reservation, config_file)
      write_configuration(server_config_file(config_file), config_body)
    end
    write_custom_whitelist(reservation) if reservation.custom_whitelist_id.present?
    reservation.status_update('Finished sending reservation config files')
  end

  def enable_plugins
    write_configuration(sourcemod_file, sourcemod_body)
  end

  def add_sourcemod_admin(user)
    write_configuration(sourcemod_admin_file, sourcemod_admin_body(user))
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

  def sourcemod_admin_file
    "#{tf_dir}/addons/sourcemod/configs/admins_simple.ini"
  end

  def sourcemod_admin_body(user)
    uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(user.uid.to_i)
    flags = sdr? ? 'abcdefghijkln' : 'z'
    <<-INI
    "#{uid3}" "99:#{flags}"
    INI
  end

  def write_custom_whitelist(reservation)
    write_configuration(server_config_file("custom_whitelist_#{reservation.custom_whitelist_id}.txt"), reservation.custom_whitelist_content)
  end

  def generate_config_file(reservation, config_file)
    template         = File.read(Rails.root.join("lib/#{config_file}.erb"))
    renderer         = ERB.new(template)
    renderer.result(reservation.get_binding)
  end

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
    if supports_mitigations?
      if reservation.server.sdr?
        reservation.enable_sdr_mitigations
      else
        reservation.enable_mitigations
      end
    end

    update_configuration(reservation)
    if reservation.enable_plugins? || reservation.enable_demos_tf?
      reservation.status_update('Enabling plugins')
      enable_plugins
      add_sourcemod_admin(reservation.user) unless reservation.server.sdr?
      reservation.status_update('Enabled plugins')
      if reservation.enable_demos_tf?
        reservation.status_update('Enabling demos.tf')
        enable_demos_tf
        reservation.status_update('Enabled demos.tf')
      end
    end
    if reservation.server.outdated?
      reservation.status_update('Server outdated, restarting server to update')
      clear_sdr_info!
      restart
      reservation.status_update('Restarted server, waiting to boot')
    else
      reservation.status_update('Attempting fast start')
      if rcon_exec("removeip 1; removeip 1; removeip 1; sv_logsecret #{reservation.logsecret}; logaddress_add direct.#{SITE_HOST}:40001")
        first_map = reservation.first_map.presence || 'ctf_turbine'
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

  def update_reservation(reservation)
    update_configuration(reservation)
  end

  def end_reservation(reservation)
    DisableMitigationsWorker.perform_async(reservation.id) if supports_mitigations?
    reservation.reload
    return if reservation.ended?

    remove_configuration
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

  def rcon_exec(command)
    condenser.rcon_exec(command) if rcon_auth
  rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout, SteamCondenser::Error::RCONNoAuth, SteamCondenser::Error::RCONBan => e
    Rails.logger.error "Couldn't deliver command to server #{id} - #{name}, command: #{command}, exception: #{e}"
    nil
  end

  def rcon_exec!(command)
    condenser.rcon_exec(command)
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

  def steam_connect_url(ip, port, password)
    "steam://connect/#{ip}:#{port}/#{CGI.escape(password)}"
  end

  def clear_sdr_info!
    persisted? && sdr? && update_columns(last_sdr_ip: nil, last_sdr_port: nil, last_sdr_tv_port: nil)
  end

  private

  def logs_and_demos
    @logs_and_demos ||= logs + demos
  end

  def log_match
    File.join(tf_dir, 'logs', '*.log')
  end

  def demo_match
    File.join(tf_dir, '*.dem')
  end

  def server_config_file(config_file)
    "#{tf_dir}/cfg/#{config_file}"
  end

  def configuration_files
    [reservation_config_file, initial_map_config_file, banned_user_file, banned_ip_file]
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

  def host_to_ip
    Resolv.getaddress(ip) unless Rails.env.test?
  end
end
