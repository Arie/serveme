class Server < ActiveRecord::Base
  attr_accessible :name, :path, :ip, :port

  has_many :groups, :through => :group_servers
  has_many :group_servers
  has_many :reservations

  def self.reservable_by_user(user)
    without_group + in_groups(user.groups)
  end

  def self.without_group
    all - with_group
  end

  def self.with_group
    Server.joins(:groups)
  end

  def self.in_groups(groups)
    with_group.
    where(:groups => { :id => groups }).
    group('servers.id')
  end

  def info
    "#{name} - connect #{ip_port}; password"
  end

  def ip_port
    "#{ip}:#{port}"
  end

  def update_configuration(reservation)
    template         = File.read(Rails.root.join("lib/reservation.cfg.erb"))
    renderer         = ERB.new(template)
    output_content   = renderer.result(reservation.get_binding)
    output_filename  = "#{path}/orangebox/tf/cfg/reservation.cfg"
    File.open(output_filename, 'w') do |f|
      f.write(output_content)
    end
  end

  def remove_configuration
    if File.exists?("#{path}/orangebox/tf/cfg/reservation.cfg")
      File.delete("#{path}/orangebox/tf/cfg/reservation.cfg")
    end
  end

  def restart
    logger.info "Killing process id #{process_id}"
    Process.kill(15, process_id)
  end

  def process_id
    @process_id ||= begin
                      pid = `ps ux | grep 'port #{port}' | grep 'srcds_linux' | grep -v grep | grep -v ruby | awk '{print $2}'`.to_i
                      if pid > 0
                        pid
                      end
                    end
  end

end
