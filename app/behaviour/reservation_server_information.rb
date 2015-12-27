# frozen_string_literal: true
module ReservationServerInformation
  def server_name
    "#{server.name} (##{id})"
  end

  def connect_string
    server.server_connect_string(password)
  end

  def stv_connect_string
    server.stv_connect_string(tv_password)
  end

  def rcon_string
    "rcon_address #{server.ip}:#{server.port}; rcon_password #{rcon}"
  end

  def server_connect_url
    server.server_connect_url(password)
  end

  def stv_connect_url
    server.stv_connect_url(tv_password)
  end

  def zipfile_name
    "#{user.uid}-#{id}-#{server.id}-#{formatted_starts_at}.zip"
  end

  def zipfile_url
    "#{SITE_URL}/uploads/#{zipfile_name}"
  end

  def has_players?
    last_number_of_players.to_i > 0
  end

end
