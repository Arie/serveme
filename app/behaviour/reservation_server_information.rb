# typed: false
# frozen_string_literal: true

module ReservationServerInformation
  extend T::Sig

  sig { returns(String) }
  def server_name
    "#{SITE_HOST} (##{id})"
  end

  sig { returns(T.nilable(String)) }
  def public_ip
    (server&.sdr? && sdr_ip) || server&.public_ip
  end

  sig { returns(T.nilable(Integer)) }
  def public_port
    (server&.sdr? && sdr_port&.to_i) || server&.public_port&.to_i
  end

  sig { returns(T.nilable(String)) }
  def connect_sdr_ip
    sdr_ip || server&.last_sdr_ip
  end

  sig { returns(T.nilable(Integer)) }
  def connect_sdr_port
    sdr_port&.to_i || server&.last_sdr_port&.to_i
  end

  sig { returns(T.nilable(Integer)) }
  def connect_sdr_tv_port
    sdr_tv_port&.to_i || server&.last_sdr_tv_port&.to_i
  end

  sig { returns(T.nilable(Integer)) }
  def public_tv_port
    (server&.sdr? && sdr_tv_port&.to_i) || server&.public_tv_port&.to_i
  end

  sig { returns(String) }
  def connect_string
    server.connect_string(public_ip, public_port, password)
  end

  sig { returns(String) }
  def stv_connect_string
    server.connect_string(public_ip, public_tv_port, tv_password)
  end

  sig { returns(String) }
  def sdr_connect_string
    server.connect_string(connect_sdr_ip, connect_sdr_port, password)
  end

  sig { returns(String) }
  def sdr_stv_connect_string
    server.connect_string(connect_sdr_ip, connect_sdr_tv_port, tv_password)
  end

  sig { returns(String) }
  def rcon_string
    if server
      "rcon_address #{server.ip}:#{server.port}; rcon_password \"#{rcon}\""
    else
      "rcon_password \"#{rcon}\""
    end
  end

  sig { returns(T.nilable(String)) }
  def server_connect_url
    server&.steam_connect_url(public_port, password)
  end

  sig { returns(T.nilable(String)) }
  def stv_connect_url
    server&.steam_connect_url(public_tv_port, tv_password)
  end

  sig { returns(String) }
  def zipfile_name
    "#{user.uid}-#{id}-#{server_id}-#{formatted_starts_at}.zip"
  end

  sig { returns(String) }
  def zipfile_url
    "#{SITE_URL}/uploads/#{zipfile_name}"
  end

  sig { returns(T::Boolean) }
  def players_playing?
    last_number_of_players.to_i.positive?
  end
end
