class ServerInfo

  attr_accessor :server, :server_connection

  delegate :condenser, :to => :server, :prefix => false

  def initialize(server)
    @server            = server
    @server_connection = condenser
  end

  def auth
    server.rcon_auth
  end

  def server_name
    ActiveSupport::Multibyte::Chars.new(status.fetch(:server_name, 'unknown'.freeze)).tidy_bytes.to_s
  end

  def number_of_players
    status.fetch(:number_of_players,  nil).freeze
  end

  def max_players
    status.fetch(:max_players,        '0'.freeze).freeze
  end

  def map_name
    status.fetch(:map_name,           'unknown'.freeze).freeze
  end

  def status
    Rails.cache.fetch "server_info_#{server.id}", expires_in: 1.minute do
      begin
        info = server_connection.server_info
        info.delete_if {|key| key == :content_data }.freeze
      rescue SteamCondenser::Error, Errno::ECONNREFUSED
        {}
      end
    end
  end

  def get_stats
    Rails.cache.fetch "stats_#{server.id}", expires_in: 1.minute do
      auth
      server_connection.rcon_exec('stats'.freeze).freeze
    end
  end

  def get_rcon_status
    Rails.cache.fetch "rcon_status_#{server.id}", expires_in: 1.minute do
      auth
      ActiveSupport::Multibyte::Chars.new(server_connection.rcon_exec('status'.freeze)).to_s.freeze
    end
  end

  def cpu
    stats[:cpu].freeze
  end

  def traffic_in
    stats[:in].freeze
  end

  def traffic_out
    stats[:out].freeze
  end

  def uptime
    stats[:uptime].freeze
  end

  def map_changes
    stats[:map_changes].freeze
  end

  def fps
    stats[:fps].freeze
  end

  def connects
    stats[:connects].freeze
  end

  def stats
    stats_line = ""
    #CPU    In (KB/s)  Out (KB/s)  Uptime  Map changes  FPS      Players  Connects
    #24.88  35.29      54.48       6       2            66.67    9        12
    get_stats.each_line do |line|
      stats_line = line
    end
    items = stats_line.split(" ")
    {
      :cpu          => items[-8].freeze,
      :in           => items[-7].freeze,
      :out          => items[-6].freeze,
      :uptime       => items[-5].freeze,
      :map_changes  => items[-4].freeze,
      :fps          => items[-3].freeze,
      :connects     => items[-1].freeze
    }
  end

end
