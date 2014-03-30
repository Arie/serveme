class LogWorker
  include Sidekiq::Worker

  attr_accessor :raw_line, :line, :event, :reservation_id

  def perform(raw_line)
    @raw_line         = raw_line
    if reservation
      handle_event
    end
  end

  def handle_event
    if event.is_a?(TF2LineParser::Events::Say) && said_by_reserver?
      handle_message(event.message)
    end
  end

  def handle_message(message)
    action = valid_actions[message]
    send(action) if action
  end

  def handle_end
    Rails.logger.info "Ending #{reservation} from chat"
    reservation.server.rcon_say "Ending your reservation, zipfile with logs and demos can be downloaded here in a minute: #{reservation.zipfile_url}"
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

  def valid_actions
    {
      "!end"    => "handle_end",
      "!extend" => "handle_extend"
    }
  end


  def said_by_reserver?
    event.player.steam_id == reserver_steam_id
  end

  def reserver
    @reserver ||= reservation.user
  end

  def reserver_steam_id
    @reserver_steam_id ||= SteamCondenser::Community::SteamId.community_id_to_steam_id(reserver.uid.to_i)
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
    matches = raw_line.match('(?\'secret\'\d*)(?\'line\'.*)')
    if matches
      if matches[:line]
        @line = matches[:line]
      end
      if matches[:secret].present?
        Rails.cache.fetch("reservation_secret_#{matches[:secret]}") do
          @reservation_id = Reservation.where(:logsecret => matches[:secret]).last.try(:id)
        end
      end
    end
  end

end
