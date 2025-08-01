# typed: true
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
    firewall_allow_players if current_reservation.server.supports_mitigations?
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
        rp = ReservationPlayer.where(reservation: current_reservation, steam_uid: player.steam_uid, ip: player.ip).first_or_create
        rp.update(name: name)
        PlayerStatistic.create!(reservation_player: rp,
                                ping: player.ping,
                                loss: player.loss,
                                minutes_connected: player.minutes_connected)
      end
    end

    CurrentPlayersService.expire_cache
    broadcast_players_update
  end

  def remove_banned_players
    parser.players.each do |player|
      next unless banned_player?(player)

      uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(player.steam_uid.to_i)
      if banned_asn?(player)
        server.rcon_exec "kickid #{player.user_id} [#{SITE_HOST}] Please play without VPN; addip 0 #{player.ip}"
        Rails.logger.info "Removed player on VPN with UID #{player.steam_uid}, IP #{player.ip}, name #{player.name}, from reservation #{current_reservation.id}"
      else
        ban_reason = banned_uid?(player) || banned_ip?(player)
        server.rcon_exec "kickid #{player.user_id} #{ban_reason}; banid 0 #{uid3}; addip 0 #{player.ip}"
        Rails.logger.info "Removed banned player with UID #{player.steam_uid}, IP #{player.ip}, name #{player.name}, from reservation #{current_reservation.id}"
      end
    end
  end

  def firewall_allow_players
    steam_uids = parser&.players&.map(&:steam_uid)

    ReservationPlayer.where(reservation: current_reservation, steam_uid: steam_uids).where(whitelisted: [ nil, false ]).each do |rp|
      Rails.logger.info("Found unwhitelisted player with uid #{rp.steam_uid} for reservation #{current_reservation.id}")
      current_reservation.allow_reservation_player(rp)
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
    return "banned" if ReservationPlayer.banned_name?(name)

    name
  end

  private

  def whitelisted_player?(player)
    ReservationPlayer.whitelisted_uid?(player.steam_uid)
  end

  def banned_player?(player)
    return false if whitelisted_player?(player)

    banned_uid?(player) || banned_ip?(player) || banned_asn?(player)
  end

  def banned_asn?(player)
    ReservationPlayer.banned_asn_ip?(player.ip)
  end

  def banned_uid?(player)
    ReservationPlayer.banned_uid?(player.steam_uid)
  end

  def banned_ip?(player)
    ReservationPlayer.banned_ip?(player.ip)
  end

  def broadcast_players_update
    servers_with_players = CurrentPlayersService.all_servers_with_current_players
    distance_unit = CurrentPlayersService.distance_unit_for_region

    Turbo::StreamsChannel.broadcast_replace_to(
      "players",
      target: "players-content",
      partial: "players/players_content",
      locals: {
        servers_with_players: servers_with_players,
        distance_unit: distance_unit
      }
    )
  end
end
