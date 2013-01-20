class ServerInfo

  attr_accessor :server, :server_connection

  def initialize(server)
    @server            = server
    @server_connection = SteamCondenser::SourceServer.new(@server.ip, @server.port.to_i)
  end

  def number_of_players
    status.fetch(:number_of_players, '0')
  end

  def max_players
    status.fetch(:max_players, '0')
  end

  def players
    server_connection.players
  end

  def status
    cache 'status' do
      server_connection.server_info.delete_if {|key| key == :content_data }
    end
  end

  def stats
    get_stats.each_line do |line|
      line
    end
  end

  def get_stats
    cache 'stats' do
      server_connection.rcon_exec('stats')
    end
  end

  def fps
    stats.split(" ")[-3]
  end

  def cpu
    stats.split(" ")[-8]
  end

  def auth
    server_connection.rcon_auth(server.current_rcon)
  end

  def cache(key, &block)
    Rails.cache.fetch "#{key}_#{server.id}" do
      yield block
    end
  end

end
