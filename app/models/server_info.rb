# typed: true
# frozen_string_literal: true

class ServerInfo
  extend T::Sig

  attr_accessor :server, :server_connection

  delegate :condenser, to: :server, prefix: false

  sig { params(server: T.any(Server, OpenStruct)).void }
  def initialize(server)
    @server            = server
    @server_connection = condenser
  end

  sig { returns(T.nilable(T::Boolean)) }
  def auth
    server.rcon_auth
  end

  sig { returns(String) }
  def server_name
    status.fetch(:server_name, "unknown").to_s
  end

  sig { returns(T.nilable(Integer)) }
  def version
    status.fetch(:version, nil)
  end

  sig { returns(T.nilable(String)) }
  def ip
    status.fetch(:ip, nil)
  end

  sig { returns(T.nilable(Integer)) }
  def port
    status.fetch(:port, nil)
  end

  sig { returns(T.nilable(Integer)) }
  def number_of_players
    status.fetch(:number_of_players,  nil)
  end

  sig { returns(Integer) }
  def max_players
    status.fetch(:max_players,        0)
  end

  sig { returns(String) }
  def map_name
    status.fetch(:map_name,           "unknown")
  end

  sig { returns(Hash) }
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
          out[:max_players] ||= Regexp.last_match(2).to_i
        end
      end
      out
    rescue SteamCondenser::Error, Errno::ECONNREFUSED
      {}
    end
  end

  sig { returns(String) }
  def fetch_stats
    Rails.cache.fetch "stats_#{server.id}", expires_in: 1.minute do
      auth
      server_connection.rcon_exec("stats").to_s
    end
  end

  sig { returns(String) }
  def fetch_rcon_status
    Rails.cache.fetch "rcon_status_#{server.id}", expires_in: 1.minute do
      auth
      server_connection.rcon_exec("status").to_s
    end
  end

  sig { returns(T.nilable(String)) }
  def cpu
    stats[:cpu]
  end

  sig { returns(T.nilable(String)) }
  def traffic_in
    stats[:in]
  end

  sig { returns(T.nilable(String)) }
  def traffic_out
    stats[:out]
  end

  sig { returns(T.nilable(String)) }
  def uptime
    stats[:uptime]
  end

  sig { returns(T.nilable(String)) }
  def map_changes
    stats[:map_changes]
  end

  sig { returns(T.nilable(String)) }
  def fps
    stats[:fps]
  end

  sig { returns(T.nilable(String)) }
  def connects
    stats[:connects]
  end

  sig { returns(Hash) }
  def stats
    stats_line = ""
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

  sig { returns(Hash) }
  def fetch_realtime_stats
    cache_key = "realtime_stats_#{server.id}"
    lock_key = "realtime_stats_lock_#{server.id}"

    cached_result = T.let(Rails.cache.read(cache_key), T.untyped)
    return cached_result if cached_result

    lock_result = T.let(nil, T.nilable(Hash))
    lock_result = $lock.synchronize(lock_key, retries: 5, initial_wait: 0.05, expiry: 3.seconds) do
      cached_result_inner = T.let(Rails.cache.read(cache_key), T.untyped)
      next cached_result_inner if cached_result_inner

      auth
      combined_output = server_connection.rcon_exec("stats; status").to_s

      stats_section = combined_output.split("\n").first(2).join("\n")
      Rails.cache.write("stats_#{server.id}", stats_section, expires_in: 1.second)
      current_stats = stats

      status_lines = combined_output.lines.drop_while { |line| !line.include?("hostname:") }
      status_section = status_lines.join
      Rails.cache.write("rcon_status_#{server.id}", status_section, expires_in: 1.second)
      current_status = status

      player_pings = []
      player_count = 0

      combined_output.each_line do |line|
        next if line.match?(/^#\s*\d+\s+"[^"]+"\s+BOT\s+/)
        match = line.match(/^#\s*\d+\s+"([^"]+)"\s+\[U:\d+:\d+\]\s+[\d:]+\s+(\d+)\s+\d+\s+active/)
        if match
          player_pings << { name: match[1], ping: match[2].to_i }
          player_count += 1
        end
      end

      result_hash = {
        fps: current_stats[:fps]&.to_f || 0,
        cpu: current_stats[:cpu]&.to_f || 0,
        traffic_in: current_stats[:in]&.to_f || 0,
        traffic_out: current_stats[:out]&.to_f || 0,
        player_count: current_status[:number_of_players] || player_count,
        player_pings: player_pings.sort_by { |player| player[:name].downcase }
      }

      Rails.cache.write(cache_key, result_hash, expires_in: 0.9.seconds)
      Rails.cache.write("#{cache_key}_stale", result_hash, expires_in: 10.seconds)
      result_hash
    end

    if lock_result.nil?
      cached_result = Rails.cache.read(cache_key) || Rails.cache.read("#{cache_key}_stale")
      return cached_result if cached_result

      return {
        fps: 0,
        cpu: 0,
        traffic_in: 0,
        traffic_out: 0,
        player_count: 0,
        player_pings: []
      }
    end

    lock_result
  rescue => e
    Rails.logger.error("Failed to fetch realtime stats: #{e.message}")
    raise
  end
end
