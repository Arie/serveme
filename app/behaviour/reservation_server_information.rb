# frozen_string_literal: true

module ReservationServerInformation
  def server_name
    "#{SITE_HOST} (##{id})"
  end

  def connect_string
    server&.server_connect_string(password)
  end

  def stv_connect_string
    server&.stv_connect_string(tv_password)
  end

  def rcon_string
    if server
      "rcon_address #{server.ip}:#{server.port}; rcon_password \"#{rcon}\""
    else
      "rcon_password \"#{rcon}\""
    end
  end

  def server_connect_url
    server&.server_connect_url(password)
  end

  def stv_connect_url
    server&.stv_connect_url(tv_password)
  end

  def zipfile_name
    "#{user.uid}-#{id}-#{server.id}-#{formatted_starts_at}.zip"
  end

  def zipfile_url
    "#{SITE_URL}/uploads/#{zipfile_name}"
  end

  def players_playing?
    last_number_of_players.to_i.positive?
  end
end
