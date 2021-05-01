# frozen_string_literal: true

class ServerMetric
  delegate :server, :map_name, :cpu, :traffic_in, :traffic_out, :uptime, :fps, to: :server_info

  attr_reader :server_info

  def initialize(server_info)
    @server_info = server_info

    return unless current_reservation

    save_server_statistics

    return unless players_playing?

    save_player_statistics
    remove_banned_players
  end

  def save_server_statistics
    ServerStatistic.create!(server_id: server.id,
                            reservation_id: current_reservation.id,
                            cpu_usage: cpu.to_f.round,
                            fps: fps.to_f.round,
                            number_of_players: number_of_players,
                            map_name: map_name,
                            traffic_in: traffic_in.to_f.round,
                            traffic_out: traffic_out.to_f.round)
  end

  def save_player_statistics
    PlayerStatistic.transaction do
      parser.players.each do |player|
        next unless player.relevant?

        name = sanitize_name(player.name)
        rp = ReservationPlayer.where(reservation: current_reservation, steam_uid: player.steam_uid).first_or_create(name: name, ip: player.ip)
        PlayerStatistic.create!(reservation_player: rp,
                                ping: player.ping,
                                loss: player.loss,
                                minutes_connected: player.minutes_connected)
      end
    end
  end

  def remove_banned_players
    parser.players.each do |player|
      next unless (ReservationPlayer.banned_uid?(player.steam_uid) || ReservationPlayer.banned_ip?(player.ip)) && !ReservationPlayer.whitelisted_uid?(player.steam_uid)

      uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(player.steam_uid.to_i)
      server.rcon_exec "banid 0 #{uid3} kick"
      Rails.logger.info "Removed banned player with UID #{player.steam_uid}, IP #{player.ip}, name #{player.name}"
    end
  end

  def parser
    @parser ||= RconStatusParser.new(server_info.fetch_rcon_status)
  end

  def current_reservation
    @current_reservation ||= server.current_reservation
  end

  def number_of_players
    server_info.number_of_players.to_i
  end

  def players_playing?
    number_of_players.positive?
  end

  def sanitize_name(name)
    return 'banned' if ReservationPlayer.banned_name?(name)

    name
  end
end
