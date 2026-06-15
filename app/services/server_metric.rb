# typed: true
# frozen_string_literal: true

class ServerMetric
  extend T::Sig

  delegate :server, :map_name, :cpu, :traffic_in, :traffic_out, :uptime, :fps, to: :server_info

  attr_reader :server_info

  sig { params(server_info: ServerInfo).void }
  def initialize(server_info)
    @server_info = server_info

    return unless current_reservation

    save_server_statistics

    if players_playing?
      save_player_statistics
      remove_banned_players
      firewall_allow_players if T.must(T.must(current_reservation).server).supports_mitigations?
    end
  end

  sig { void }
  def save_server_statistics
    ServerStatistic.create!(server_id: server.id,
                            reservation_id: T.must(current_reservation).id,
                            cpu_usage: cpu.to_f.round,
                            fps: fps.to_f.round,
                            number_of_players: number_of_players,
                            map_name: map_name,
                            traffic_in: traffic_in.to_f.round,
                            traffic_out: traffic_out.to_f.round)
  end

  sig { void }
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
  end

  sig { void }
  def remove_banned_players
    parser.players.each do |player|
      next unless banned_player?(player)

      uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(player.steam_uid.to_i)
      if banned_asn?(player)
        server.rcon_exec "kickid #{player.user_id} [#{SITE_HOST}] Please play without VPN; addip 0 #{player.ip}"
        Rails.logger.info "Removed player on VPN with UID #{player.steam_uid}, IP #{player.ip}, name #{player.name}, from reservation #{T.must(current_reservation).id}"
      else
        ban_reason = banned_uid?(player) || banned_ip?(player)
        server.rcon_exec "kickid #{player.user_id} #{ban_reason}; banid 0 #{uid3}; addip 0 #{player.ip}"
        Rails.logger.info "Removed banned player with UID #{player.steam_uid}, IP #{player.ip}, name #{player.name}, from reservation #{T.must(current_reservation).id}"
      end
    end
  end

  sig { void }
  def firewall_allow_players
    parser.players.each do |player|
      next unless player.relevant?

      rp = ReservationPlayer.find_by(reservation: current_reservation, steam_uid: player.steam_uid, ip: player.ip)
      next unless rp
      next if rp.whitelisted?

      if ReservationPlayer.sdr_ip?(player.ip)
        next if ReservationPlayer.whitelisted_uid?(player.steam_uid)

        Rails.logger.info("Found unwhitelisted SDR player #{player.name} (#{player.steam_uid}) for reservation #{T.must(current_reservation).id}")

        CheckSdrSteamProfileWorker.perform_async(rp.id)

        unless ReservationPlayer.sdr_eligible_steam_profile?(player.steam_uid)
          server.rcon_exec "kickid #{player.user_id} Please connect normally before joining with SDR; addip 1 #{player.ip}"
          Rails.logger.info "Kicked SDR player #{player.name} (#{player.steam_uid}) without normal IP history from reservation #{T.must(current_reservation).id}"
        end

        rp.update(whitelisted: true)
      else
        Rails.logger.info("Found unwhitelisted player with uid #{rp.steam_uid} for reservation #{T.must(current_reservation).id}")
        T.must(current_reservation).allow_reservation_player(rp)
      end
    end
  end

  sig { returns(RconStatusParser) }
  def parser
    @parser ||= RconStatusParser.new(server_info.fetch_rcon_status)
  end

  sig { returns(T.nilable(Reservation)) }
  def current_reservation
    @current_reservation ||= server.current_reservation
  end

  sig { returns(Integer) }
  def number_of_players
    server_info.number_of_players.to_i
  end

  sig { returns(T::Boolean) }
  def players_playing?
    number_of_players.positive?
  end

  sig { params(name: String).returns(String) }
  def sanitize_name(name)
    return "banned" if ReservationPlayer.banned_name?(name)

    name
  end

  private

  sig { params(player: RconStatusParser::Player).returns(T.nilable(T.any(String, T::Boolean))) }
  def whitelisted_player?(player)
    ReservationPlayer.whitelisted_uid?(player.steam_uid)
  end

  sig { params(player: RconStatusParser::Player).returns(T.nilable(T.any(String, T::Boolean))) }
  def banned_player?(player)
    return false if whitelisted_player?(player)

    banned_uid?(player) || banned_ip?(player) || banned_asn?(player)
  end

  sig { params(player: RconStatusParser::Player).returns(T.nilable(T::Boolean)) }
  def banned_asn?(player)
    ReservationPlayer.banned_asn_ip?(player.ip)
  end

  sig { params(player: RconStatusParser::Player).returns(T.nilable(T.any(String, T::Boolean))) }
  def banned_uid?(player)
    ReservationPlayer.banned_uid?(player.steam_uid)
  end

  sig { params(player: RconStatusParser::Player).returns(T.nilable(T.any(String, T::Boolean))) }
  def banned_ip?(player)
    ReservationPlayer.banned_ip?(player.ip)
  end
end
