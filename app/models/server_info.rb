# frozen_string_literal: true
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
        out = {}
        get_rcon_status.lines.each do |line|
          case line
          when /^hostname\W+(.*)$/
            out[:server_name] ||= $1
          when /^map\W+(\S+)/
            out[:map_name] ||= $1
          when /^players\W+(\S+).+\((\d+)/
            out[:number_of_players] ||= $1.to_i
            out[:max_players] ||= $2
          end
        end
        out
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
      ActiveSupport::Multibyte::Chars.new(server_connection.rcon_exec('status'.freeze)).tidy_bytes.to_s
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

  def stats
    stats_line = ""
    #CPU   NetIn   NetOut    Uptime  Maps   FPS   Players  Svms    +-ms   ~tick
    #10.0      11.0      12.0     883     2   10.00       0  243.12    4.45    4.46|
    get_stats.each_line do |line|
      stats_line = line
    end
    items = stats_line.split(" ")
    {
      :cpu          => items[0].freeze,
      :in           => items[1].freeze,
      :out          => items[2].freeze,
      :uptime       => items[3].freeze,
      :map_changes  => items[4].freeze,
      :fps          => items[5].freeze,
    }
  end

end
