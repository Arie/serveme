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
    write_configuration(output_filename, output_content)
  end

  def process_id
    @process_id ||= find_process_id
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
    rescue Exception => exception
      Raven.capture_exception(exception) if Rails.env.production?
      true
    end
  end

  private

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

end
