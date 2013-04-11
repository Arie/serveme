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
    File.join(path, 'orangebox', 'tf')
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
    begin
      ServerInfo.new(self).number_of_players > 0
    rescue Errno::ECONNREFUSED, SteamCondenser::TimeoutError
      #Just assume it's occupied when the server times out or isn't up
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

  private

  def logs_and_demos
    @logs_and_demos ||= logs + demos
  end

  def log_match
    File.join(tf_dir, 'logs', "L*.log")
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
