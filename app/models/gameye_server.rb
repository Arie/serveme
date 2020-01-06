# frozen_string_literal: true
class GameyeServer < Server

  has_one :reservation, foreign_key: :server_id

  def self.start_reservation(reservation)
    Rails.logger.info("Starting Gameye server")
    launched = launch_gameye(reservation)
    if launched.is_a?(Hash)
      create_temporary_server(reservation, launched)
    else
      reservation.status_update("Failed to launch Gameye server, got #{launched}")
    end
  end

  def self.update_reservation(reservation); end

  def self.create_temporary_server(reservation, launched)
    server = GameyeServer.create(
      name: "Gameye ##{reservation.id}",
      ip: launched["host"],
      port: launched["port"]["game"],
      tv_port: launched["port"]["hltv"],
      rcon: reservation.rcon
    )
    reservation.update_attribute(:server_id, server.id)
    reservation.status_update("Created Gameye match connect #{server.ip}:#{server.port}; password #{reservation.password}")
  end

  def self.stop_reservation(reservation)
    Rails.logger.info("Stopping Gameye server ##{reservation.id}")
    reservation.server.update_attribute(:active, false)
    Gameye::Match.stop(match_key: gameye_id(reservation))
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
    if SITE_HOST == "na.serveme.tf"
      [
        {id: "new_york", name: "New York", flag: "us", concurrency_limit: 0},
        {id: "washington_dc", name: "Washington D.C.", flag: "us", concurrency_limit: 10},
        {id: "san_francisco", name: "San Francisco", flag: "us", concurrency_limit: 0},
        {id: "san_jose", name: "San Jose", flag: "us", concurrency_limit: 10},
        {id: "dallas", name: "Dallas", flag: "us", concurrency_limit: 10}
      ]
    else
      [
        {id: "london", name: "London", flag: "en", concurrency_limit: 10},
        {id: "frankfurt", name: "Frankfurt", flag: "de", concurrency_limit: 10},
        {id: "madrid", name: "Madrid", flag: "es", concurrency_limit: 10},
        {id: "moscow", name: "Moscow", flag: "ru", concurrency_limit: 10},
        {id: "sao_paulo", name: "São Paulo", flag: "br", concurrency_limit: 5},
        {id: "warsaw", name: "Warsaw", flag: "pl", concurrency_limit: 10}
      ]
    end
  end

  def self.location_keys
    locations.map do |location|
      location[:id]
    end
  end

  def self.launch_gameye(reservation)
    Gameye::Match.start(
      game_key: "tf2-serveme",
      template_key: "serveme",
      match_key: gameye_id(reservation),
      location_keys: [reservation.gameye_location],
      options: {
        hostname: "Gameye ##{reservation.id}",
        map: reservation.first_map,
        rconPassword: reservation.rcon,
        serverPassword: reservation.password,
        logAddress: "direct.#{SITE_HOST}:40001",
        logSecret: "#{reservation.logsecret}",
        maxPlayers: 24,
        stvPassword: reservation.tv_password,
        sourceTvDelay: 90,
        motd: "This is a #{SITE_HOST} cloud server",
        whitelist: reservation.custom_whitelist_id,
        config: (reservation.server_config && reservation.server_config.file)
      }
    )
  end

  def self.gameye_id(reservation)
    "#{SITE_HOST}-#{reservation.id}"
  end

  def end_reservation(reservation)
    reservation.reload
    return if reservation.ended?
    rcon_exec("sv_logflush 1; tv_stoprecord; kickall Reservation ended, every player can download the STV demo at http:/​/#{SITE_HOST}")
    sleep 1 # Give server a second to finish the STV demo and write the log
    GameyeServer.stop_reservation(reservation)
  end

  def update_configuration(_reservation); end
  def write_configuration(_output_filename, _output_content); end
  def upload_configuration(_configuration_file, _upload_file); end
  def remove_configuration; end
  def remove_logs_and_demos; end
  def list_files(_destination); [] end
  def copy_to_server(_files, destination); end
  def restart; end
end
