# frozen_string_literal: true

class ServerInfo
  attr_accessor :server, :server_connection

  delegate :condenser, to: :server, prefix: false

  def initialize(server)
    @server            = server
    @server_connection = condenser
  end

  def auth
    server.rcon_auth
  end

  def server_name
    status.fetch(:server_name, 'unknown').to_s
  end

  def version
    status.fetch(:version, nil)
  end

  def ip
    status.fetch(:ip, nil)
  end

  def port
    status.fetch(:port, nil)
  end

  def number_of_players
    status.fetch(:number_of_players,  nil)
  end

  def max_players
    status.fetch(:max_players,        '0')
  end

  def map_name
    status.fetch(:map_name,           'unknown')
  end

  def status
    Rails.cache.fetch "server_info_#{server.id}", expires_in: 1.minute do
      out = {}
      fetch_rcon_status.lines.each do |line|
        case line
        when /^version\s+:\s+(\d+)/
          out[:version] ||= Regexp.last_match(1)&.to_i
        when %r{^udp/ip\s+:\s+(\d+\.\d+\.\d+\.\d+):(\d+)}
          out[:ip] ||= Regexp.last_match(1)
          out[:port] ||= Regexp.last_match(2)&.to_i
        when /^hostname\W+(.*)$/
          out[:server_name] ||= Regexp.last_match(1)
        when /^map\W+(\S+)/
          out[:map_name] ||= Regexp.last_match(1)
        when /^players\W+(\S+).+\((\d+)/
          out[:number_of_players] ||= Regexp.last_match(1).to_i
          out[:max_players] ||= Regexp.last_match(2)
        end
      end
      out
    rescue SteamCondenser::Error, Errno::ECONNREFUSED
      {}
    end
  end

  def fetch_stats
    Rails.cache.fetch "stats_#{server.id}", expires_in: 1.minute do
      auth
      server_connection.rcon_exec('stats')
    end
  end

  def fetch_rcon_status
    Rails.cache.fetch "rcon_status_#{server.id}", expires_in: 1.minute do
      auth
      server_connection.rcon_exec('status').to_s
    end
  end

  def cpu
    stats[:cpu]
  end

  def traffic_in
    stats[:in]
  end

  def traffic_out
    stats[:out]
  end

  def uptime
    stats[:uptime]
  end

  def map_changes
    stats[:map_changes]
  end

  def fps
    stats[:fps]
  end

  def connects
    stats[:connects]
  end

  def stats
    stats_line = ''
    # CPU    In (KB/s)  Out (KB/s)  Uptime  Map changes  FPS      Players  Connects
    # 24.88  35.29      54.48       6       2            66.67    9        12
    fetch_stats.each_line do |line|
      stats_line = line
    end
    items = stats_line.split
    {
      cpu: items[-8],
      in: items[-7],
      out: items[-6],
      uptime: items[-5],
      map_changes: items[-4],
      fps: items[-3],
      connects: items[-1].freeze
    }
  end
end
