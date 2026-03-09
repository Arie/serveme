# typed: false
# frozen_string_literal: true

require "unicode/name"

class WhoisPlayerWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(reservation_id, query, requester_uid, is_reserver = false)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation&.server

    server = reservation.server
    status_output = server.rcon_exec("status")
    return unless status_output

    players = RconStatusParser.new(status_output).players.select(&:relevant?)
    matched = match_players(players, query).sort_by { |p| p.name.downcase }

    if matched.empty?
      send_message(server, "No players matching '#{query}'", requester_uid)
    else
      matched.each do |player|
        info = PlayerAnnouncementService.build_info(player.steam_uid, player.ip, reserver: is_reserver)
        send_message(server, "#{player.name}: #{info}", requester_uid)
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
        player.steam_uid.to_s.include?(query) ||
        searchable_emoji_name(player.name).include?(query_downcase)
    end
  end

  def searchable_emoji_name(name)
    name.each_char.filter_map { |c| Unicode::Name.of(c)&.downcase if c.ord > 0xFF }.join(" ")
  end

  def send_message(server, message, requester_uid)
    message.split("\n").each do |line|
      line.scan(/.{1,200}(?:\s|$)/).map(&:strip).each do |chunk|
        server.rcon_exec("sm_psay ##{requester_uid} #{chunk}")
      end
    end
  end
end
