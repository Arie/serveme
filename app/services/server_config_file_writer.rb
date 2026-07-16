# typed: true
# frozen_string_literal: true

# Generates and writes a server's reservation config files (server/map cfgs,
# rgl_base democheck cfg, sourcemod plugin + admin files, MOTD, whitelist,
# maplist). Extracted from Server so the model stays focused on persistence;
# Server delegates the config-writing methods here. The actual file transport
# (write_configuration / delete_from_server) stays polymorphic on the server.
class ServerConfigFileWriter
  extend T::Sig

  sig { params(server: Server).void }
  def initialize(server)
    @server = server
  end

  sig { params(reservation: Reservation).returns(ReservationStatus) }
  def update_configuration(reservation)
    reservation.status_update("Sending reservation config files")
    [ "reservation.cfg", "ctf_turbine.cfg" ].each do |config_file|
      config_body = generate_config_file(reservation, config_file)
      @server.write_configuration(server_config_file(config_file), config_body)
    end
    handle_rgl_base_cfg(reservation)
    add_motd(reservation)
    write_custom_whitelist(reservation) if reservation.custom_whitelist_id.present?
    write_maplist
    reservation.status_update("Finished sending reservation config files")
  end

  sig { params(reservation: Reservation).returns(T.untyped) }
  def handle_rgl_base_cfg(reservation)
    original_cfg_path = Rails.root.join("doc", "rgl_base.cfg")
    content = File.read(original_cfg_path)

    case reservation.democheck_mode
    when "warn"
      modified_content = content.gsub("sm_democheck_warn 0", "sm_democheck_warn 1")
      @server.write_configuration(server_config_file("rgl_base.cfg"), modified_content)
    when "disable"
      modified_content = content
        .gsub("sm_democheck_enabled 1", "sm_democheck_enabled 0")
        .gsub("sm_democheck_announce 1", "sm_democheck_announce 0")
      @server.write_configuration(server_config_file("rgl_base.cfg"), modified_content)
    else
      @server.write_configuration(server_config_file("rgl_base.cfg"), content)
    end
    true
  end

  sig { returns(T.untyped) }
  def restore_rgl_base_cfg
    original_cfg_path = Rails.root.join("doc", "rgl_base.cfg")
    content = File.read(original_cfg_path)
    @server.write_configuration(server_config_file("rgl_base.cfg"), content)
    true
  end

  sig { void }
  def write_maplist
    maps_text = Rails.cache.fetch("api_maps_text", expires_in: 10.minutes) do
      MapUpload.available_maps.sort.join("\n")
    end
    @server.write_configuration(server_config_file("maplist_full.txt"), maps_text)
  end

  sig { returns(T.untyped) }
  def enable_plugins
    @server.write_configuration(sourcemod_file, sourcemod_body)
  end

  sig { params(user: User).returns(T.untyped) }
  def add_sourcemod_admin(user)
    T.must(@server.write_configuration(sourcemod_admin_file, sourcemod_admin_body(user)))
  end

  sig { params(reservation: Reservation).returns(T.untyped) }
  def add_motd(reservation)
    T.must(@server.write_configuration(motd_file, motd_body(reservation)))
  end

  sig { returns(T.untyped) }
  def disable_plugins
    @server.delete_from_server([ sourcemod_file, sourcemod_admin_file ])
  end

  sig { returns(String) }
  def sourcemod_file
    "#{@server.tf_dir}/addons/metamod/sourcemod.vdf"
  end

  sig { returns(String) }
  def sourcemod_body
    <<-VDF
    "Metamod Plugin"
    {
      "alias"		"sourcemod"
      "file"		"addons/sourcemod/bin/sourcemod_mm"
    }
    VDF
  end

  sig { params(reservation: Reservation).returns(String) }
  def motd_body(reservation)
    "#{SITE_URL}/reservations/#{reservation.id}/motd?password=#{URI.encode_uri_component(reservation.password)}"
  end

  sig { returns(String) }
  def sourcemod_admin_file
    "#{@server.tf_dir}/addons/sourcemod/configs/admins_simple.ini"
  end

  sig { params(user: User).returns(String) }
  def sourcemod_admin_body(user)
    uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(user.uid.to_i)
    flags = @server.sdr? ? "abcdefghijkln" : "z"
    <<-INI
    "#{uid3}" "99:#{flags}"
    INI
  end

  sig { params(reservation: Reservation).returns(T.untyped) }
  def write_custom_whitelist(reservation)
    content = reservation.custom_whitelist_content
    return unless content

    @server.write_configuration(server_config_file("custom_whitelist_#{reservation.custom_whitelist_id}.txt"), content)
  end

  sig { params(object: Reservation, config_file: String).returns(String) }
  def generate_config_file(object, config_file)
    template = File.read(Rails.root.join("lib/#{config_file}.erb"))
    renderer = ERB.new(template)
    renderer.result(object.get_binding)
  end

  private

  # Config file paths derive from the server's polymorphic tf_dir; computed here
  # rather than calling Server's private server_config_file/motd_file.
  sig { params(config_file: String).returns(String) }
  def server_config_file(config_file)
    "#{@server.tf_dir}/cfg/#{config_file}"
  end

  sig { returns(String) }
  def motd_file
    "#{@server.tf_dir}/motd.txt"
  end
end
