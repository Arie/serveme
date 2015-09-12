class ServerMetric

  delegate :server, :map_name, :cpu, :traffic_in, :traffic_out, :uptime, :fps, :to => :server_info

  attr_reader :server_info

  def initialize(server_info)
    @server_info = server_info
    if current_reservation && players_playing?
      save_server_statistics
      save_player_statistics
    end
    nil
  end

  def save_server_statistics
    ServerStatistic.create!(:server_id         => server.id,
                            :reservation_id    => current_reservation.id,
                            :cpu_usage         => cpu.to_f.round,
                            :fps               => fps.to_f.round,
                            :number_of_players => number_of_players,
                            :map_name          => map_name,
                            :traffic_in        => traffic_in.to_f.round,
                            :traffic_out       => traffic_out.to_f.round)
  end

  def save_player_statistics
    parser = RconStatusParser.new(server_info.get_rcon_status)
    PlayerStatistic.transaction do
      parser.players.each do |player|
        if player.relevant?
          rp = ReservationPlayer.where(:reservation => current_reservation, :steam_uid => player.steam_uid).first_or_create(:name => player.name, :ip => player.ip)
          PlayerStatistic.create!(:reservation_player => rp,
                                  :ping               => player.ping,
                                  :loss               => player.loss,
                                  :minutes_connected  => player.minutes_connected
                                 )
        end


      end
    end
  end


  def current_reservation
    @current_reservation ||= server.current_reservation
  end

  def number_of_players
    server_info.number_of_players.to_i
  end

  def players_playing?
    number_of_players > 0
  end

end
