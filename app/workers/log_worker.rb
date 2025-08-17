# typed: false
# frozen_string_literal: true

require File.expand_path("../models/concerns/steam_id_anonymizer", __dir__)

class LogWorker
  include Sidekiq::Worker
  include SteamIdAnonymizer
  extend T::Sig
  sidekiq_options retry: 1

  attr_accessor :raw_line, :line, :message

  MAP_START         = /(Started map\ "(\w+)")/
  END_COMMAND       = /^!end.*/
  EXTEND_COMMAND    = /^!extend.*/
  RCON_COMMAND      = /^!rcon.*/
  SDR_INFO_COMMAND  = /^!sdr.*/
  WEB_RCON_COMMAND = /^(\.|!)webrcon.*/
  TIMELEFT_COMMAND  = /^!timeleft.*/
  WHOIS_RESERVER    = /^!who$/
  AI_COMMAND        = /^!ai\s+(.+)/
  LOCK_COMMAND      = /^!lock.*/
  UNLOCK_COMMAND    = /^!unlock.*/
  UNBANALL_COMMAND  = /^!unbanall.*/
  PASSWORD_COMMAND  = /^!password.*/
  LOG_LINE_REGEX    = '(?\'secret\'\d*)(?\'line\'.*)'


  def perform(raw_line)
    @raw_line = raw_line
    handle_event if reservation
  end

  private

  def handle_event
    case event
    when TF2LineParser::Events::Say, TF2LineParser::Events::TeamSay
      @message = event.message
      handle_message
    when TF2LineParser::Events::Connect
      handle_connect
    when TF2LineParser::Events::Disconnect
      handle_disconnect
    when TF2LineParser::Events::Unknown
      mapstart = event.unknown.match(MAP_START)
      handle_mapstart(mapstart[2]) if mapstart
    end
    Turbo::StreamsChannel.broadcast_prepend_to "reservation_#{reservation&.logsecret}_log_lines", target: "reservation_#{reservation&.logsecret}_log_lines", partial: "reservations/log_line", locals: { log_line: line }
  end

  def handle_mapstart(mapname)
    reservation&.broadcast_connect_info
    ActiveReservationCheckerWorker.perform_in(10.seconds, reservation&.id)
    if mapname == "ctf_turbine"
      reservation&.status_update("Server startup complete, switching map")
    else
      reservation&.status_update("Server finished loading map \"#{mapname}\"")
    end
  end

  def handle_message
    action = action_by_reserver || action_for_message_said_by_anyone
    return unless action

    reservation&.status_update("#{event.player.name} (#{sayer_steam_uid}): #{event.message}")
    send(action)
    reservation&.server&.rcon_disconnect
  end

  def handle_connect
    return if event.player.steam_id == "BOT"

    community_id = SteamCondenser::Community::SteamId.steam_id_to_community_id(event.player.steam_id)
    ip = event.message.to_s.split(":").first
    rp = create_or_update_reservation_player(community_id, ip)

    return unless reservation

    return if handle_locked_server_player(community_id, ip, event)
    return if handle_banned_vpn_player(community_id, ip, event)
    return if handle_banned_player(community_id, ip, event)
    return if handle_league_banned_player(community_id, ip, event)

    broadcast_player_connect(rp)
    whitelist_player_in_firewall(rp)
  end

  sig { params(community_id: Integer, ip: String).returns(ReservationPlayer) }
  def create_or_update_reservation_player(community_id, ip)
    rp = ReservationPlayer.where(reservation_id: reservation_id, ip: ip, steam_uid: community_id).first_or_create
    rp.update(name: event.player.name)
    rp
  end

  sig { params(community_id: Integer, ip: String, event: TF2LineParser::Events::Event).returns(T::Boolean) }
  def handle_locked_server_player(community_id, ip, event)
    return false unless reservation&.locked?

    return false if event.player.steam_id == reserver_steam_id

    reservation&.server&.rcon_exec "kickid #{event.player.uid} Server locked by reservation owner; banid 0 #{event.player.steam_id}"
    Rails.logger.info "Kicked player #{event.player.name} (#{community_id}) from locked reservation #{reservation_id}"
    true
  end

  sig { params(community_id: Integer, ip: String, event: TF2LineParser::Events::Event).returns(T::Boolean) }
  def handle_banned_vpn_player(community_id, ip, event)
    return false unless ReservationPlayer.banned_asn_ip?(ip) && !ReservationPlayer.whitelisted_uid?(community_id)

    reservation&.server&.rcon_exec "kickid #{event.player.uid} [#{SITE_HOST}] Please play without VPN; addip 0 #{ip}"
    Rails.logger.info "Removed player on VPN with UID #{community_id}, IP #{event.message}, name #{event.player.name}, from reservation #{reservation_id}"
    true
  end

  sig { params(community_id: Integer, ip: String, event: TF2LineParser::Events::Event).returns(T::Boolean) }
  def handle_banned_player(community_id, ip, event)
    return false unless (ban_reason = ReservationPlayer.banned_uid?(community_id) || ReservationPlayer.banned_ip?(ip)) && !ReservationPlayer.whitelisted_uid?(community_id)

    reservation&.server&.rcon_exec "kickid #{event.player.uid} #{ban_reason}; banid 0 #{event.player.steam_id}; addip 0 #{ip}"
    Rails.logger.info "Removed banned player with UID #{community_id}, IP #{event.message}, name #{event.player.name}, from reservation #{reservation_id}"
    true
  end

  sig { params(community_id: Integer, ip: String, event: TF2LineParser::Events::Event).returns(T::Boolean) }
  def handle_league_banned_player(community_id, ip, event)
    banned_league_profile = LeagueBan.fetch(community_id)
    return false unless banned_league_profile

    Rails.logger.info "League banned player with UID #{community_id}, IP #{event.message}, name #{event.player.name} connected to reservation #{reservation_id}: #{banned_league_profile.ban_reason}"

    if banned_league_profile.ban_reason.to_s.match?(/^(cheat|vac)/i)
      reservation&.server&.rcon_exec "kickid #{event.player.uid} Cheating (league ban); banid 0 #{event.player.steam_id}; addip 0 #{ip}"
    end

    reservation&.server&.rcon_say "#{banned_league_profile.league_name} banned player #{event.player.name} connected: #{banned_league_profile.ban_reason}"
    true
  end

  sig { params(reservation_player: ReservationPlayer).void }
  def whitelist_player_in_firewall(reservation_player)
    return unless reservation&.server&.supports_mitigations?

    AllowReservationPlayerWorker.perform_async(reservation_player.id)
  end

  sig { void }
  def handle_end
    Rails.logger.info "Ending #{reservation} from chat"
    reservation&.server&.rcon_say "Ending your reservation..."
    ReservationWorker.perform_async(reservation&.id, "end")
  end

  sig { void }
  def handle_extend
    if reservation&.extend!
      Rails.logger.info "Extended #{reservation} from chat"
      reservation&.server&.rcon_say "Extended your reservation by #{(reserver.reservation_extension_time / 60.0).round} minutes"
    else
      Rails.logger.info "Couldn't extend #{reservation} from chat"
      reservation&.server&.rcon_say "Couldn't extend your reservation: you can only extend when there's less than 1 hour left and no one else has booked the server."
    end
  end

  sig { void }
  def handle_sdr_connect
    if reservation&.sdr_ip && reservation&.sdr_port
      Rails.logger.info "Sending SDR info for #{reservation} after chat request from #{sayer_steam_uid}"
      reservation&.server&.rcon_say "SDR info: connect #{reservation&.sdr_ip}:#{reservation&.sdr_port}"
    else
      Rails.logger.info "Couldn't send SDR info #{reservation} after chat request from #{sayer_steam_uid}"
      reservation&.server&.rcon_say "SDR currently not available for this server, please try again in a minute or two"
    end
  end

  sig { void }
  def handle_rcon
    rcon_command = message.split[1..].join(" ")
    return if rcon_command.empty?

    if !reservation&.server&.sdr? && (reservation&.enable_plugins? || reservation&.enable_demos_tf?)
      Rails.logger.info "Ignoring rcon command #{rcon_command} from chat for reservation #{reservation}"
    else
      Rails.logger.info "Sending rcon command #{rcon_command} from chat for reservation #{reservation}"
      reservation&.server&.rcon_exec(rcon_command)
    end
  end

  sig { void }
  def handle_web_rcon
    return if reservation&.enable_plugins? || reservation&.enable_demos_tf?

    reservation&.server&.rcon_say "Plugins need to be enabled for us to show you the Web RCON page. Instead, open #{SITE_URL}/reservations/#{reservation&.id}/rcon to use Web RCON."
  end

  sig { void }
  def handle_timeleft
    minutes_until_reservation_ends = ((T.must(T.must(reservation).ends_at) - Time.current) / 60).round
    minutes = [ minutes_until_reservation_ends, 0 ].max
    timeleft = minutes.positive? ? "#{minutes} minutes" : "#{minutes} minute"
    reservation&.server&.rcon_say "Reservation time left: #{timeleft}"
  end

  sig { void }
  def handle_whois_reserver
    reservation&.server&.rcon_say "Reservation created by: '#{reserver.name}' (#{reserver.uid})"
  end

  sig { returns(T.nilable(Symbol)) }
  def action_for_message_said_by_reserver
    case message
    when END_COMMAND
      :handle_end
    when RCON_COMMAND
      :handle_rcon
    when WEB_RCON_COMMAND
      :handle_web_rcon
    when AI_COMMAND
      :handle_ai
    when LOCK_COMMAND
      :handle_lock
    when UNLOCK_COMMAND
      :handle_unlock
    when UNBANALL_COMMAND
      :handle_unbanall
    end
  end

  sig { returns(T.nilable(Symbol)) }
  def action_for_message_said_by_anyone
    case message
    when TIMELEFT_COMMAND
      :handle_timeleft
    when EXTEND_COMMAND
      :handle_extend
    when WHOIS_RESERVER
      :handle_whois_reserver
    when SDR_INFO_COMMAND
      :handle_sdr_connect
    when PASSWORD_COMMAND
      :handle_password
    end
  end

  sig { returns(T::Boolean) }
  def said_by_reserver?
    event.player.steam_id == reserver_steam_id
  end

  sig { returns(T.nilable(Symbol)) }
  def action_by_reserver
    action_for_message_said_by_reserver if said_by_reserver?
  end

  sig { returns(User) }
  def reserver
    @reserver ||= reservation&.user
  end

  sig { returns(String) }
  def reserver_steam_id
    @reserver_steam_id ||= SteamCondenser::Community::SteamId.community_id_to_steam_id3(reserver.uid.to_i)
  end

  sig { returns(Integer) }
  def sayer_steam_uid
    @sayer_steam_uid ||= SteamCondenser::Community::SteamId.steam_id_to_community_id(event.player.steam_id)
  end

  sig { returns(TF2LineParser::Events::Event) }
  def event
    @event ||= TF2LineParser::Parser.new(line).parse
  end

  sig { returns(T.nilable(Reservation)) }
  def reservation
    @reservation ||= Reservation.current.includes(:user).find_by_id(reservation_id) if reservation_id
  end

  sig { returns(T.nilable(Integer)) }
  def reservation_id
    matches = raw_line.match(LOG_LINE_REGEX)
    return unless matches

    @line = matches[:line] if matches[:line]
    return unless matches[:secret].present?

    Rails.cache.fetch("reservation_secret_#{matches[:secret]}", expires_in: 1.minute) do
      @reservation_id = Reservation.where(logsecret: matches[:secret]).pluck(:id).last
    end
  end

  sig { void }
  def handle_ai
    return unless reservation

    unless said_by_reserver?
      reservation&.server&.rcon_say("AI commands are only available to reservation creators")
      return
    end

    # Rate limit AI commands per user
    user_key = "ai_command_count:user_#{today}:#{sayer_steam_uid}"
    user_count = Rails.cache.increment(user_key, 1, expires_in: 24.hours)

    if user_count > 100
      reservation&.server&.rcon_say "Rate limited: Maximum daily AI commands (100) reached for your Steam ID"
      return
    end

    Rails.logger.info "Processing AI command #{message} from #{event.player.name} (#{SteamCondenser::Community::SteamId.steam_id_to_community_id(event.player.steam_id)})"

    ai_command = message.match(AI_COMMAND)[1]
    AiCommandHandler.new(reservation).process_request(ai_command)
  end

  sig { void }
  def handle_lock
    return unless reservation

    reservation.lock!
    reservation&.status_update("Server locked by #{event.player.name}, password changed and no new connects allowed")
    Rails.logger.info "Locked server for reservation #{reservation.id}"
  end

  sig { void }
  def handle_unlock
    return unless reservation&.locked?

    if reservation.unlock!
      reservation&.server&.rcon_exec "say Server unlocked, original password restored!"
      reservation&.status_update("Server unlocked by #{event.player.name} (#{sayer_steam_uid})")
      Rails.logger.info "Unlocked server for reservation #{reservation.id} by #{sayer_steam_uid}"
    end
  end

  sig { void }
  def handle_unbanall
    return unless reservation

    Rails.logger.info "Unbanning all players for reservation #{reservation.id} by #{sayer_steam_uid}"

    result = reservation.unban_all!

    if result[:count].nil?
      reservation&.server&.rcon_say result[:message]
      Rails.logger.warn "Failed to parse listid result for reservation #{reservation.id}"
    elsif result[:count] == 0
      reservation&.server&.rcon_say result[:message]
      Rails.logger.info "No players to unban for reservation #{reservation.id}"
    else
      reservation&.server&.rcon_say result[:message]
      reservation&.status_update("All #{result[:count]} banned player#{'s' if result[:count] != 1} unbanned by #{event.player.name} (#{sayer_steam_uid})")
      Rails.logger.info "#{result[:message]} for reservation #{reservation.id}"
    end
  end

  sig { void }
  def handle_password
    return unless reservation

    if reservation&.enable_plugins?
      player_uniqueid = event.player.uid
      player_name = event.player.name
      current_password = reservation.password
      reservation&.server&.rcon_exec "sm_psay ##{player_uniqueid} Server password: #{current_password}"
      Rails.logger.info "Sent password to #{player_name} (#{sayer_steam_uid}) for reservation #{reservation.id}"
    else
      reservation&.server&.rcon_say "Password can't be sent via DM - plugins are disabled for this reservation"
      Rails.logger.info "Password request denied for #{event.player.name} (#{sayer_steam_uid}) - plugins disabled for reservation #{reservation.id}"
    end
  end

  def handle_disconnect
    return if event.player.steam_id == "BOT"

    community_id = SteamCondenser::Community::SteamId.steam_id_to_community_id(event.player.steam_id)

    rp = ReservationPlayer.find_by(reservation: reservation, steam_uid: community_id)
    broadcast_player_disconnect(rp) if rp && reservation
  end

  def broadcast_player_connect(reservation_player)
    return unless reservation&.server

    server = reservation.server
    player_data = {
      steam_uid: anonymize_steam_id(reservation_player.steam_uid.to_s),
      server_id: server.id,
      server_name: server.name,
      server_location: server.detailed_location,
      server_latitude: server.latitude,
      server_longitude: server.longitude
    }

    if reservation_player.ip.present?
      location_info = CurrentPlayersService.get_player_location_info(reservation_player)
      if location_info[:player_latitude] && location_info[:player_longitude]
        player_data.merge!(
          player_latitude: location_info[:player_latitude],
          player_longitude: location_info[:player_longitude],
          country_code: location_info[:country_code],
          country_name: location_info[:country_name],
          city_name: location_info[:city_name]
        )
      end
    end

    Turbo::StreamsChannel.broadcast_append_to(
      "player_globe_updates",
      target: "globe-container",
      partial: "players/globe_player_connect",
      locals: { player_data: player_data }
    )
  end

  def broadcast_player_disconnect(reservation_player)
    return unless reservation&.server_id

    Turbo::StreamsChannel.broadcast_append_to(
      "player_globe_updates",
      target: "globe-container",
      partial: "players/globe_player_disconnect",
      locals: {
        steam_uid: anonymize_steam_id(reservation_player.steam_uid.to_s),
        server_id: reservation.server_id
      }
    )
  end

  def today
    @today ||= Time.current.in_time_zone(time_zone).to_date
  end

  def time_zone
    @time_zone ||= case SITE_HOST
    when "na.serveme.tf"
      "America/Chicago"
    when "sea.serveme.tf"
      "Asia/Singapore"
    when "au.serveme.tf"
      "Australia/Sydney"
    else
      "Europe/Amsterdam"
    end
  end
end
