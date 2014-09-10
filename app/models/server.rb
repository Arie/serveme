class Server < ActiveRecord::Base

  attr_accessible :name, :path, :ip, :port

  has_many :groups, :through => :group_servers
  has_many :group_servers
  has_many :reservations
  belongs_to :location

  validates_presence_of :name
  validates_presence_of :ip
  validates_presence_of :port
  validates_presence_of :path

  delegate :flag, :to => :location, :prefix => true, :allow_nil => true

  def self.reservable_by_user(user)
    where(:id => ids_reservable_by_user(user))
  end

  def self.ids_reservable_by_user(user)
    without_group.pluck(:id) + in_groups(user.groups).pluck(:id)
  end

  def self.ordered
    order('servers.position ASC, servers.name ASC')
  end

  def self.without_group
    if with_group.any?
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

  def self.in_groups(groups)
    with_group.
    where(:groups => { :id => groups.map(&:id) }).
    group('servers.id')
  end

  def self.for_donators
    Group.donator_group.servers
  end

  def server_connect_string(password)
    connect_string(ip, port, password)
  end

  def stv_connect_string(tv_password)
    connect_string(ip, port.to_i + 5, tv_password)
  end

  def server_connect_url(password)
    steam_connect_url(ip, port, password)
  end

  def stv_connect_url(password)
    steam_connect_url(ip, port.to_i + 5, password)
  end

  def update_configuration(reservation)
    ['reservation.cfg', 'ctf_turbine.cfg'].each do |config_file|
      config_body = generate_config_file(reservation, config_file)
      write_configuration(server_config_file(config_file), config_body)
    end
  end

  def enable_plugins
    write_configuration(metamod_file, metamod_body)
  end

  def disable_plugins
    delete_from_server([metamod_file])
  end

  def metamod_file
    "#{tf_dir}/addons/metamod.vdf"
  end

  def metamod_body
    <<-VDF
    "Plugin"
    {
      "file"	"../tf/addons/metamod/bin/server"
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

  def tf_dir
    File.join(path, 'tf')
  end

  def current_rcon
    if current_reservation && current_reservation.provisioned?
      current_reservation.rcon
    else
      rcon
    end
  end

  def current_reservation
    reservations.current.first
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

  def restart
    if process_id
      logger.info "Killing process id #{process_id}"
      kill_process
    else
      logger.error "No process_id found for server #{id} - #{name}"
    end
  end

  def start_reservation(reservation)
    update_configuration(reservation)
    #enable_plugins if reservation.enable_plugins?
    restart
  end

  def update_reservation(reservation)
    update_configuration(reservation)
  end

  def end_reservation(reservation)
    rcon_exec("log off; tv_stoprecord")
    remove_configuration
    disable_plugins
    zip_demos_and_logs(reservation)
    copy_logs(reservation)
    remove_logs_and_demos
    rcon_exec("kickall Reservation ended, every player can download the STV demo at http:/​/#{SITE_HOST}")
    restart
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

  def set_logaddress
    rcon_exec("logaddress_add #{SITE_HOST}:40001")
  end

  def rcon_say(message)
    rcon_exec("say #{message}")
  end

  def rcon_exec(command)
    begin
      condenser.rcon_exec(command) if rcon_auth
    rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout, SteamCondenser::Error::RCONNoAuth, SteamCondenser::Error::RCONBan => exception
      Rails.logger.error "Couldn't deliver command to server #{id} - #{name}, command: #{command}"
    end
  end

  def number_of_players
    begin
      @number_of_players ||= ServerInfo.new(self).number_of_players
    rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout
      nil
    end
  end

  private

  def logs_and_demos
    @logs_and_demos ||= logs + demos
  end

  def log_match
    File.join(tf_dir, 'logs', "*.log")
  end

  def demo_match
    File.join(tf_dir, "*.dem")
  end

  def connect_string(ip, port, password)
    "connect #{ip}:#{port}; password #{password}"
  end

  def steam_connect_url(ip, port, password)
    "steam://connect/#{ip}:#{port}/#{password}"
  end

  def server_config_file(config_file)
    "#{tf_dir}/cfg/#{config_file}"
  end

  def reservation_config_file
    server_config_file('reservation.cfg')
  end

  def initial_map_config_file
    server_config_file('ctf_turbine.cfg')
  end

end
