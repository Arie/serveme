# typed: false
# frozen_string_literal: true

class CurrentPlayersService
  def self.all_servers_with_current_players
    recent_stats = PlayerStatistic.joins(reservation_player: { reservation: :server })
                                  .where("player_statistics.created_at >= ?", 90.seconds.ago)
                                  .includes(reservation_player: { reservation: :server })
                                  .order("servers.name ASC, player_statistics.created_at DESC")

    servers_hash = {}

    recent_stats.each do |stat|
      server = stat.reservation_player.reservation.server
      servers_hash[server.id] ||= { server: server, players_by_uid: {} }

      steam_uid = stat.reservation_player.steam_uid
      unless servers_hash[server.id][:players_by_uid][steam_uid]
        player_info = get_player_location_info(stat.reservation_player)
        servers_hash[server.id][:players_by_uid][steam_uid] = {
          player_statistic: stat,
          reservation_player: stat.reservation_player,
          country_code: player_info[:country_code],
          country_name: player_info[:country_name],
          city_name: player_info[:city_name],
          distance: player_info[:distance],
          player_latitude: player_info[:player_latitude],
          player_longitude: player_info[:player_longitude],
          sdr: player_info[:sdr],
          asn_number: stat.reservation_player.asn_number,
          asn_organization: stat.reservation_player.asn_organization,
          asn_network: stat.reservation_player.asn_network
        }
      end
    end

    servers_with_players = servers_hash.values.map do |server_data|
      players = server_data[:players_by_uid].values
                                           .sort_by { |player| player[:reservation_player]&.name&.downcase || "zzz" }

      {
        server: server_data[:server],
        players: players
      }
    end

    servers_with_players.sort_by { |server_data| server_data[:server].name.downcase }
  end

  def self.cached_servers_with_current_players
    Rails.cache.fetch("servers_with_current_players", expires_in: 30.seconds) do
      all_servers_with_current_players
    end
  end

  def self.get_player_location_info(reservation_player)
    if reservation_player.ip && reservation_player.ip.start_with?("169.254.")
      return { country_code: nil, country_name: nil, city_name: nil, distance: nil, player_latitude: nil, player_longitude: nil, sdr: true }
    end

    return { country_code: nil, country_name: nil, city_name: nil, distance: nil, player_latitude: nil, player_longitude: nil } if local_ip?(reservation_player.ip)

    geocoding_result = Geocoder.search(reservation_player.ip).first
    return { country_code: nil, country_name: nil, city_name: nil, distance: nil, player_latitude: nil, player_longitude: nil } unless geocoding_result

    country_code = geocoding_result.country_code
    country_name = geocoding_result.country
    city_name = geocoding_result.city

    server = reservation_player.reservation.server
    distance = nil
    if server&.latitude && server&.longitude && geocoding_result.latitude && geocoding_result.longitude
      distance_km = Geocoder::Calculations.distance_between(
        [ server.latitude, server.longitude ],
        [ geocoding_result.latitude, geocoding_result.longitude ]
      )

      distance_unit = distance_unit_for_region
      distance = case distance_unit
      when "mi"
                   (distance_km * 0.621371).round
      else
                   distance_km.round
      end
    end

    {
      country_code: country_code&.downcase,
      country_name: country_name,
      city_name: city_name,
      distance: distance,
      player_latitude: geocoding_result.latitude,
      player_longitude: geocoding_result.longitude
    }
  end

  def self.local_ip?(ip)
    return false unless ip

    ip_addr = IPAddr.new(ip)
    local_ranges = [
      IPAddr.new("169.254.0.0/16"),  # SDR
      IPAddr.new("10.0.0.0/8"),      # Private
      IPAddr.new("172.16.0.0/12"),   # Private
      IPAddr.new("192.168.0.0/16"),  # Private
      IPAddr.new("127.0.0.0/8")      # Loopback
    ]

    local_ranges.any? { |range| range.include?(ip_addr) }
  rescue IPAddr::InvalidAddressError
    true
  end


  def self.distance_unit_for_region
    SITE_URL == "https://na.serveme.tf" ? "mi" : "km"
  end

  def self.expire_cache
    Rails.cache.delete("servers_with_current_players")
    Rails.cache.delete("views/players_content")
  end
end
