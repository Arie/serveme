class Server < ActiveRecord::Base
  attr_accessible :name, :path, :ip, :port

  has_many :groups, :through => :group_servers
  has_many :group_servers
  has_many :reservations

  def self.reservable_by_user(user)
    without_group + in_groups(user.groups)
  end

  def self.without_group
    scoped - with_group
  end

  def self.with_group
    joins(:groups)
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
    output_filename  = "#{tf_dir}/cfg/reservation.cfg"
    File.open(output_filename, 'w') do |f|
      f.write(output_content)
    end
  end

  def remove_configuration
    if File.exists?("#{tf_dir}/cfg/reservation.cfg")
      File.delete("#{tf_dir}/cfg/reservation.cfg")
    end
  end

  def restart
    if process_id
      logger.info "Killing process id #{process_id}"
      Process.kill(15, process_id)
    else
      logger.error "No process_id found for server #{id} - #{name}"
    end
  end

  def process_id
    @process_id ||= find_process_id
  end

  def find_process_id
    all_processes   = Sys::ProcTable.ps
    found_processes = all_processes.select {|process| process.cmdline.match(/#{port}/) && process.cmdline.match(/\.\/srcds_linux/) }
    if found_processes.any?
      found_processes.first.pid
    end
  end

  def tf_dir
    File.join(path, 'orangebox', 'tf')
  end

  def demos
    demo_match = File.join(tf_dir, "*.dem")
    Dir.glob(demo_match)
  end

  def logs
    log_match = File.join(tf_dir, 'logs', "L*.log")
    Dir.glob(log_match)
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

  def occupied?
    begin
      ServerInfo.new(self).number_of_players > 0
    rescue Exception => exception
      Raven.capture_exception(exception) if Rails.env.production?
      true
    end
  end

  private

  def connect_string(ip, port, password)
    "connect #{ip}:#{port}; password #{password}"
  end

  def steam_connect_url(ip, port, password)
    "steam://connect/#{ip}:#{port}/#{password}"
  end

end
