# typed: false
# frozen_string_literal: true

class LogWorker
  include Sidekiq::Worker
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
  LOG_LINE_REGEX    = '(?\'secret\'\d*)(?\'line\'.*)'

  def perform(raw_line)
    @raw_line = raw_line
    handle_event if reservation
  end

  def handle_event
    case event
    when TF2LineParser::Events::Say, TF2LineParser::Events::TeamSay
      @message = event.message
      handle_message
    when TF2LineParser::Events::Connect
      handle_connect
    when TF2LineParser::Events::Unknown
      mapstart = event.unknown.match(MAP_START)
      handle_mapstart(mapstart[2]) if mapstart
    end
    Turbo::StreamsChannel.broadcast_prepend_to "reservation_#{reservation.logsecret}_log_lines", target: "reservation_#{reservation.logsecret}_log_lines", partial: 'reservations/log_line', locals: { log_line: line }
  end

  def handle_mapstart(mapname)
    reservation.broadcast_connect_info
    ActiveReservationCheckerWorker.perform_in(10.seconds, reservation.id)
    if mapname == 'ctf_turbine'
      reservation.status_update('Server startup complete, switching map')
    else
      reservation.status_update("Server finished loading map \"#{mapname}\"")
    end
  end

  def handle_message
    action = action_by_reserver || action_for_message_said_by_anyone
    return unless action

    reservation.status_update("#{event.player.name} (#{sayer_steam_uid}): #{event.message}")
    send(action)
    reservation.server.rcon_disconnect
  end

  def handle_connect
    community_id = SteamCondenser::Community::SteamId.steam_id_to_community_id(event.player.steam_id)
    ip = event.message.to_s.split(':').first
    rp = ReservationPlayer.where(reservation_id: reservation_id, ip: ip, steam_uid: community_id).first_or_create
    rp.update(name: event.player.name)

    if ReservationPlayer.banned_asn_ip?(ip) && !ReservationPlayer.whitelisted_uid?(community_id)
      reservation.server.rcon_exec "kickid \"#{event.player.steam_id}\"[#{SITE_HOST}] Please play without VPN\""
      reservation.server.rcon_exec "addip 0 #{ip}"
      Rails.logger.info "Removed player on VPN with UID #{community_id}, IP #{event.message}, name #{event.player.name}, from reservation #{reservation_id}"
    elsif (ReservationPlayer.banned_uid?(community_id) || ReservationPlayer.banned_ip?(ip)) && !ReservationPlayer.whitelisted_uid?(community_id)
      reservation.server.rcon_exec "banid 0 #{event.player.steam_id} kick; addip 0 #{ip}"
      Rails.logger.info "Removed banned player with UID #{community_id}, IP #{event.message}, name #{event.player.name}, from reservation #{reservation_id}"
    elsif (banned_league_profile = LeagueBan.fetch(community_id))
      Rails.logger.info "League banned player with UID #{community_id}, IP #{event.message}, name #{event.player.name} connected to reservation #{reservation_id}: #{banned_league_profile.ban_reason}"
    elsif reservation.server.supports_mitigations?
      AllowReservationPlayerWorker.perform_async(rp.id)
    end
  end

  def handle_end
    Rails.logger.info "Ending #{reservation} from chat"
    reservation.server.rcon_say 'Ending your reservation...'
    ReservationWorker.perform_async(reservation.id, 'end')
  end

  def handle_extend
    if reservation.extend!
      Rails.logger.info "Extended #{reservation} from chat"
      reservation.server.rcon_say "Extended your reservation by #{(reserver.reservation_extension_time / 60.0).round} minutes"
    else
      Rails.logger.info "Couldn't extend #{reservation} from chat"
      reservation.server.rcon_say "Couldn't extend your reservation: you can only extend when there's less than 1 hour left and no one else has booked the server."
    end
  end

  def handle_sdr_connect
    if reservation.sdr_ip && reservation.sdr_port
      Rails.logger.info "Sending SDR info for #{reservation} after chat request from #{sayer_steam_uid}"
      reservation.server.rcon_say "SDR info: connect #{reservation.sdr_ip}:#{reservation.sdr_port}"
    else
      Rails.logger.info "Couldn't send SDR info #{reservation} after chat request from #{sayer_steam_uid}"
      reservation.server.rcon_say 'SDR currently not available for this server, please try again in a minute or two'
    end
  end

  def handle_rcon
    rcon_command = message.split[1..].join(' ')
    return if rcon_command.empty?

    if !reservation.server.sdr? && (reservation.enable_plugins? || reservation.enable_demos_tf?)
      Rails.logger.info "Ignoring rcon command #{rcon_command} from chat for reservation #{reservation}"
    else
      Rails.logger.info "Sending rcon command #{rcon_command} from chat for reservation #{reservation}"
      reservation.server.rcon_exec(rcon_command)
    end
  end

  def handle_web_rcon
    return if reservation.enable_plugins? || reservation.enable_demos_tf?

    reservation.server.rcon_say "Plugins need to be enabled for us to show you the Web RCON page. Instead, open #{SITE_URL}/reservations/#{reservation.id}/rcon to use Web RCON."
  end

  def handle_timeleft
    minutes_until_reservation_ends = ((reservation.ends_at - Time.current) / 60).round
    minutes = [minutes_until_reservation_ends, 0].max
    timeleft = minutes.positive? ? "#{minutes} minutes" : "#{minutes} minute"
    reservation.server.rcon_say "Reservation time left: #{timeleft}"
  end

  def handle_whois_reserver
    reservation.server.rcon_say "Reservation created by: '#{reserver.name}' (#{reserver.uid})"
  end

  def action_for_message_said_by_reserver
    case message
    when END_COMMAND
      :handle_end
    when RCON_COMMAND
      :handle_rcon
    when WEB_RCON_COMMAND
      :handle_web_rcon
    end
  end

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
    end
  end

  def said_by_reserver?
    event.player.steam_id == reserver_steam_id
  end

  def action_by_reserver
    said_by_reserver? && action_for_message_said_by_reserver
  end

  def reserver
    @reserver ||= reservation.user
  end

  def reserver_steam_id
    @reserver_steam_id ||= SteamCondenser::Community::SteamId.community_id_to_steam_id3(reserver.uid.to_i)
  end

  def sayer_steam_uid
    @sayer_steam_uid ||= SteamCondenser::Community::SteamId.steam_id_to_community_id(event.player.steam_id)
  end

  def event
    @event ||= TF2LineParser::Parser.new(line).parse
  end

  def reservation
    @reservation ||= Reservation.current.includes(:user).find_by_id(reservation_id) if reservation_id
  end

  def reservation_id
    matches = raw_line.match(LOG_LINE_REGEX)
    return unless matches

    @line = matches[:line] if matches[:line]
    return unless matches[:secret].present?

    Rails.cache.fetch("reservation_secret_#{matches[:secret]}", expires_in: 1.minute) do
      @reservation_id = Reservation.where(logsecret: matches[:secret]).pluck(:id).last
    end
  end
end
