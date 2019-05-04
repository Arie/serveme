# frozen_string_literal: true
class GameyeServer < Server

  def self.start(reservation)
    Rails.logger.info("Starting Gameye server")
    if launch_gameye(reservation)
      create_temporary_server(reservation)
    end
  end

  def self.create_temporary_server(reservation)
    match = fetch_match(gameye_id(reservation))
    if match
      GameyeServer.create(
        name: "Gameye ##{reservation.id}",
        ip: match.host,
        port: match.port
      )
    end
  end

  def self.stop(reservation)
    Rails.logger.info("Stopping Gameye server")
    Gameye::Match.stop(match_key: gameye_id(reservation))
  end

  def self.matches
    Gameye::Match.all
  end

  def self.fetch_match(match_key)
    matches.find do |m|
      m.match_key == match_key
    end
  end

  def self.locations
    #Gameye::Location.fetch(game_key: "tf2-serveme").locations
    #["washington_dc", "frankfurt", "chicago", "amsterdam", "phoenix"]
    ["amsterdam", "frankfurt"].map(&:capitalize)
  end

  def launch_gameye(reservation)
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
        config: reservation.config.file
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
end
