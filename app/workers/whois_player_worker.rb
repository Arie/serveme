# typed: false
# frozen_string_literal: true

class WhoisPlayerWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(reservation_id, query, private_to_uid = nil)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation&.server

    server = reservation.server
    status_output = server.rcon_exec("status")
    return unless status_output

    players = RconStatusParser.new(status_output).players.select(&:relevant?)
    matched = match_players(players, query)

    if matched.empty?
      send_message(server, "No players matching '#{query}'", private_to_uid)
    else
      matched.each do |player|
        info = PlayerAnnouncementService.build_info(player.steam_uid, player.ip)
        send_message(server, "#{player.name}: #{info}", private_to_uid)
      end
    end

    server.rcon_disconnect
  end

  private

  def match_players(players, query)
    return players if query == "*"

    query_downcase = query.downcase
    players.select do |player|
      player.name.downcase.include?(query_downcase) ||
        player.steam_id.downcase.include?(query_downcase) ||
        player.steam_uid.to_s.include?(query)
    end
  end

  def send_message(server, message, private_to_uid)
    if private_to_uid
      server.rcon_exec("sm_psay ##{private_to_uid} #{message}")
    else
      server.rcon_say(message)
    end
  end
end
