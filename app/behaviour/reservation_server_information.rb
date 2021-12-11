# frozen_string_literal: true

module ReservationServerInformation
  def server_name
    "#{SITE_HOST} (##{id})"
  end

  def public_ip
    sdr_ip || server&.public_ip
  end

  def public_port
    sdr_port || server&.public_port
  end

  def public_tv_port
    sdr_tv_port || server&.public_tv_port
  end

  def connect_string
    server.connect_string(public_ip, public_port, password)
  end

  def stv_connect_string
    server.connect_string(public_ip, public_tv_port, tv_password)
  end

  def rcon_string
    if server
      "rcon_address #{server.ip}:#{server.port}; rcon_password \"#{rcon}\""
    else
      "rcon_password \"#{rcon}\""
    end
  end

  def server_connect_url
    server&.steam_connect_url(public_ip, public_port, password)
  end

  def stv_connect_url
    server&.steam_connect_url(public_ip, public_tv_port, tv_password)
  end

  def zipfile_name
    "#{user.uid}-#{id}-#{server_id}-#{formatted_starts_at}.zip"
  end

  def zipfile_url
    "#{SITE_URL}/uploads/#{zipfile_name}"
  end

  def players_playing?
    last_number_of_players.to_i.positive?
  end
end
