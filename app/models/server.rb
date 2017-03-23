# frozen_string_literal: true
class Server < ActiveRecord::Base

  has_many :groups, :through => :group_servers
  has_many :group_servers
  has_many :reservations
  has_many :current_reservations, -> { where("reservations.starts_at <= ? AND reservations.ends_at >=?", Time.current, Time.current) }, class_name: "Reservation"
  has_many :ratings, :through => :reservations
  has_many :recent_server_statistics, -> { where("server_statistics.created_at >= ?", 2.minutes.ago).order("server_statistics.id DESC") }, class_name: "ServerStatistic"
  has_many :server_statistics
  belongs_to :location

  validates_presence_of :name
  validates_presence_of :ip
  validates_presence_of :port
  validates_presence_of :path

  geocoded_by :host_to_ip
  before_save :geocode, :if => :ip_changed?

  delegate :flag, :to => :location, :prefix => true, :allow_nil => true

  def self.reservable_by_user(user)
    where(:id => ids_reservable_by_user(user))
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
    with_group.
    where(groups: { id: groups.pluck(:id) }).
    group('servers.id')
  end

  def self.for_donators
    Group.donator_group.servers
  end

  def server_connect_string(password)
    connect_string(ip, port, password)
  end

  def stv_connect_string(tv_password)
    connect_string(ip, tv_port, tv_password)
  end

  def server_connect_url(password)
    steam_connect_url(ip, port, password)
  end

  def stv_connect_url(password)
    steam_connect_url(ip, tv_port, password)
  end

  def tv_port
    port.to_i + 5
  end

  def update_configuration(reservation)
    reservation.status_update("Sending reservation config files")
    ['reservation.cfg', 'autoexec.cfg'].each do |config_file|
      config_body = generate_config_file(reservation, config_file)
      write_configuration(server_config_file(config_file), config_body)
    end
    reservation.status_update("Finished sending reservation config files")
  end

  def enable_plugins
    write_configuration(metamod_file, metamod_body)
  end

  def disable_plugins
    delete_from_server([metamod_file])
  end

  def metamod_file
    "#{game_dir}/addons/metamod.vdf"
  end

  def metamod_body
    <<-VDF
    "Plugin"
    {
      "file"	"../csgo/addons/metamod/bin/server"
    }
    VDF
  end

  def generate_config_file(reservation, config_file)
    template         = File.read(Rails.root.join("lib/#{config_file}.erb"))
    renderer         = ERB.new(template)
    renderer.result(reservation.get_binding)
  end

  def process_id
    @process_id ||= begin
                      pid = find_process_id.to_i
                      if pid > 0
                        pid
                      end
                    end
  end

  def game_dir
    File.join(path, 'csgo')
  end

  def current_rcon
    if current_reservation && current_reservation.provisioned?
      current_reservation.rcon
    else
      rcon
    end
  end

  def current_reservation
    current_reservations.first
  end

  def inactive_minutes
    if current_reservation
      current_reservation.inactive_minute_counter
    else
      0
    end
  end

  def occupied?
    if number_of_players
      number_of_players > 0
    else
      true
    end
  end

  def start_reservation(reservation)
    update_configuration(reservation)
    enable_plugins
    reservation.status_update("Enabled plugins")
    reservation.status_update("Restarting server")
    restart
    reservation.status_update("Restarted server, waiting to boot")
  end

  def update_reservation(reservation)
    update_configuration(reservation)
  end

  def end_reservation(reservation)
    return if reservation.ended?
    remove_configuration
    disable_plugins
    rcon_exec("sv_logflush 1; tv_stoprecord; kickall Reservation ended, every player can download the STV demo at http:/​/#{SITE_HOST}")
    sleep 1 # Give server a second to finish the STV demo and write the log
    reservation.status_update("Removing configuration and disabling plugins")
    zip_demos_and_logs(reservation)
    copy_logs(reservation)
    remove_logs_and_demos
    reservation.status_update("Restarting server")
    rcon_disconnect
    restart
    reservation.status_update("Restarted server")
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
  end

  def rcon_say(message)
    rcon_exec("say #{message}")
  end

  def rcon_exec(command)
    begin
      condenser.rcon_exec(command) if rcon_auth
    rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout, SteamCondenser::Error::RCONNoAuth, SteamCondenser::Error::RCONBan => exception
      Rails.logger.error "Couldn't deliver command to server #{id} - #{name}, command: #{command}, exception: #{exception}"
      nil
    end
  end

  def rcon_disconnect
    begin
      condenser.disconnect
    rescue Exception => exception
      Rails.logger.error "Couldn't disconnect RCON of server #{id} - #{name}, exception: #{exception}"
    ensure
      @condenser = nil
    end
  end

  def number_of_players
    begin
      @number_of_players ||= server_info.number_of_players
    rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout
      nil
    end
  end

  def server_info
    @server_info ||= ServerInfo.new(self)
  end

  private

  def logs_and_demos
    @logs_and_demos ||= logs + demos
  end

  def log_match
    File.join(game_dir, 'logfiles', "*.log")
  end

  def demo_match
    File.join(game_dir, "*.dem")
  end

  def connect_string(ip, port, password)
    "connect #{ip}:#{port}; password #{password}"
  end

  def steam_connect_url(ip, port, password)
    "steam://connect/#{ip}:#{port}/#{password}"
  end

  def server_config_file(config_file)
    "#{game_dir}/cfg/#{config_file}"
  end

  def reservation_config_file
    server_config_file('reservation.cfg')
  end

  def initial_map_config_file
    server_config_file('autoexec.cfg')
  end

  def host_to_ip
    Resolv.getaddress(ip) unless Rails.env.test?
  end

end
