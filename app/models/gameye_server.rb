# frozen_string_literal: true
class GameyeServer < Server

  def self.start_reservation(reservation)
    Rails.logger.info("Starting Gameye server")
    launch = launch_gameye(reservation)
    if launch == true
      create_temporary_server(reservation)
    else
      reservation.status_update("Failed to launch Gameye server, got #{launch}")
    end
  end

  def self.update_reservation(reservation)
  end

  def self.create_temporary_server(reservation)
    match = fetch_match(gameye_id(reservation))
    if match
      server = GameyeServer.create(
        name: "Gameye ##{reservation.id}",
        ip: match.host,
        port: match.port,
        rcon: reservation.rcon
      )
      reservation.update_attribute(:server_id, server.id)
      reservation.status_update("Created Gameye match connect #{match.host}:#{match.port}; password #{reservation.password}")
    end
  end

  def self.stop_reservation(reservation)
    Rails.logger.info("Stopping Gameye server")
    Gameye::Match.stop(match_key: gameye_id(reservation))
    reservation.server.update_attribute(:active, :false)
  end

  def self.matches
    Gameye::Match.all.reject(&:nil?)
  end

  def self.fetch_match(match_key)
    matches.find do |m|
      m.match_key == match_key
    end
  end

  def self.locations
    #Gameye::Location.fetch(game_key: "tf2-serveme").locations
    #["washington_dc", "frankfurt", "chicago", "amsterdam", "phoenix"]
    ["london", "frankfurt"]
  end

  def self.launch_gameye(reservation)
    Gameye::Match.start(
      game_key: "tf2-serveme",
      template_key: "serveme",
      match_key: gameye_id(reservation),
      location_keys: [reservation.gameye_location],
      options: {
        map: reservation.first_map,
        rconPassword: reservation.rcon,
        serverPassword: reservation.password,
        stvPassword: reservation.tv_password,
        motd: "This is a serveme.tf test",
        whitelist: reservation.custom_whitelist_id,
        config: (reservation.server_config && reservation.server_config.file)
      }
    )
  end

  def self.gameye_id(reservation)
    "#{SITE_HOST}-#{reservation.id}"
  end

  def update_configuration(_reservation)
    #noop
  end
  def write_configuration(_output_filename, _output_content)
    #noop
  end
  def upload_configuration(_configuration_file, _upload_file)
    #noop
  end
  def remove_configuration
    #noop
  end
  def remove_logs_and_demos
    #noop
  end
  def restart
    #noop
  end
end
