# frozen_string_literal: true
class LogWorker
  include Sidekiq::Worker

  attr_accessor :raw_line, :line, :event, :reservation_id, :message

  MAP_START         = /(Started map\ "(\w+)")/
  END_COMMAND       = /!end.*/
  EXTEND_COMMAND    = /!extend.*/
  RCON_COMMAND      = /!rcon.*/
  TIMELEFT_COMMAND  = /!timeleft.*/
  WHOIS_RESERVER    = /^!who$/
  LOG_LINE_REGEX    = '(?\'secret\'\d*)(?\'line\'.*)'

  def perform(raw_line)
    @raw_line         = raw_line
    if reservation
      handle_event
    end
  end

  def handle_event
    if event.is_a?(TF2LineParser::Events::Say)
      @message = event.message
      handle_message
    elsif event.is_a?(TF2LineParser::Events::Unknown)
      mapstart = event.unknown.match(MAP_START)
      if mapstart
        map = mapstart[2]
        if map == "ctf_turbine"
          reservation.status_update("Server startup complete, switching map")
        else
          reservation.status_update("Server finished loading map \"#{map}\"")
        end
      end
    end
  end

  def handle_message
    action = action_by_reserver || action_for_message_said_by_anyone || action_for_message_said_by_lobby_player
    if action
      reservation.status_update("#{event.player.name} (#{sayer_steam_uid}): #{event.message}")
      send(action)
      reservation.server.rcon_disconnect
    end
  end

  def handle_end
    Rails.logger.info "Ending #{reservation} from chat"
    reservation.server.rcon_say "Ending your reservation..."
    ReservationWorker.perform_async(reservation.id, "end")
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

  def handle_rcon
    rcon_command = message.split(" ")[1..-1].join(" ")
    if !rcon_command.empty?
      Rails.logger.info "Sending rcon command #{rcon_command} from chat for reservation #{reservation}"
      reservation.server.rcon_exec(rcon_command)
    end
  end

  def handle_timeleft
    minutes_until_reservation_ends = ((reservation.ends_at - Time.current) / 60).round
    minutes = [minutes_until_reservation_ends, 0].max
    timeleft = (minutes > 0) ? "#{minutes} minutes" : "#{minutes} minutes"
    reservation.server.rcon_say "Reservation time left: #{timeleft}"
  end

  def handle_whois_reserver
    reservation.server.rcon_say "Reservation created by: '#{reserver.name}'"
  end

  def action_for_message_said_by_reserver
    case message
    when END_COMMAND
      :handle_end
    when EXTEND_COMMAND
      :handle_extend
    when RCON_COMMAND
      :handle_rcon
    end
  end

  def action_for_message_said_by_anyone
    case message
    when TIMELEFT_COMMAND
      :handle_timeleft
    when WHOIS_RESERVER
      :handle_whois_reserver
    end
  end

  def action_for_message_said_by_lobby_player
    if lobby?
      case message
      when EXTEND_COMMAND
        :handle_extend
      end
    end
  end

  def said_by_reserver?
    event.player.steam_id == reserver_steam_id
  end

  def lobby?
    reservation.lobby?
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
    if reservation_id
      @reservation ||= Reservation.includes(:user).find(reservation_id)
    end
  end

  def reservation_id
    matches = raw_line.match(LOG_LINE_REGEX)
    if matches
      if matches[:line]
        @line = matches[:line]
      end
      if matches[:secret].present?
        Rails.cache.fetch("reservation_secret_#{matches[:secret]}", expires_in: 1.minute) do
          @reservation_id = Reservation.where(:logsecret => matches[:secret]).pluck(:id).last
        end
      end
    end
  end

end
