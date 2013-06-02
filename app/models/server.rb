require 'zip_file_creator'

class Server < ActiveRecord::Base
  attr_accessible :name, :path, :ip, :port

  has_many :groups, :through => :group_servers
  has_many :group_servers
  has_many :reservations
  belongs_to :location

  def self.reservable_by_user(user)
    where(:id => ids_reservable_by_user(user))
  end

  def self.ids_reservable_by_user(user)
    without_group.map(&:id) + in_groups(user.groups).map(&:id)
  end

  def self.ordered
    ordered_by_position.ordered_by_name
  end

  def self.without_group
    scoped - with_group
  end

  def self.with_group
    joins(:groups)
  end

  def self.active
    where('servers.active = ?', true)
  end

  def self.inactive
    where('servers.active = ?', false)
  end

  def self.in_groups(groups)
    with_group.
    where(:groups => { :id => groups }).
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
    template         = File.read(Rails.root.join("lib/reservation.cfg.erb"))
    renderer         = ERB.new(template)
    output_content   = renderer.result(reservation.get_binding)
    write_configuration(reservation_config_file, output_content)
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
    if current_reservation
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
    restart
  end

  def update_reservation(reservation)
    update_configuration(reservation)
  end

  def end_reservation(reservation)
    copy_logs(reservation)
    zip_demos_and_logs(reservation)
    remove_logs_and_demos
    remove_configuration
    restart
  end

  def zip_demos_and_logs(reservation)
    ZipFileCreator.create(reservation, logs_and_demos)
  end

  def copy_logs(reservation)
    LogCopier.copy(reservation.id, self)
  end

  def condenser
    @condenser ||= SteamCondenser::SourceServer.new(ip, port.to_i)
  end

  def rcon_auth
    @rcon_auth ||= condenser.rcon_auth(current_rcon)
  end

  def rcon_say(message)
    begin
      condenser.rcon_exec("say #{message}") if rcon_auth
    rescue Errno::ECONNREFUSED, SteamCondenser::TimeoutError => exception
      Raven.capture_exception(exception) if Rails.env.production?
      Rails.logger.error "Couldn't deliver message to server #{id} - #{name}, message: #{message}"
    end
  end

  def number_of_players
    begin
      @number_of_players ||= ServerInfo.new(self).number_of_players
    rescue Errno::ECONNREFUSED, SteamCondenser::TimeoutError
      nil
    end
  end

  private

  def self.ordered_by_position
    order("servers.position ASC")
  end

  def self.ordered_by_name
    order("servers.name ASC")
  end

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

  def reservation_config_file
    "#{tf_dir}/cfg/reservation.cfg"
  end

end
