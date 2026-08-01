# typed: true
# frozen_string_literal: true

# Drives a reservation's start/update/end I/O on a server. The server's
# polymorphic primitives (restart, remove_configuration, copy_to_server,
# move_files_to_temp_directory, ...) are driven back through @server.
class ServerReservationLifecycle
  extend T::Sig

  sig { params(server: Server).void }
  def initialize(server)
    @server = server
  end

  sig { params(reservation: Reservation).void }
  def start_reservation(reservation)
    reservation.enable_mitigations if @server.supports_mitigations?

    @server.write_first_map(reservation)
    @server.update_configuration(reservation)
    if reservation.plugins_enabled?
      reservation.status_update("Enabling plugins")
      @server.enable_plugins
      @server.add_sourcemod_admin(T.must(reservation.user))
      reservation.status_update("Enabled plugins")
      if reservation.demos_tf_enabled?
        reservation.status_update("Enabling demos.tf")
        enable_demos_tf
        reservation.status_update("Enabled demos.tf")
      end
      unless reservation.democheck_kick?
        reservation.status_update("Setting RGL democheck mode to #{reservation.democheck_mode}")
        @server.handle_rgl_base_cfg(reservation)
      end
    end
    if @server.cloud?
      reservation.status_update("Config files sent, waiting for TF2 to boot")
      return
    end
    ensure_map_on_server(reservation)
    if T.must(reservation.server).outdated?
      reservation.status_update("Server outdated, restarting server to update")
      @server.clear_sdr_info!
      @server.restart
      reservation.status_update("Restarted server, waiting to boot")
    else
      reservation.status_update("Attempting fast start")
      if @server.rcon_exec("removeip 1; removeip 1; removeip 1; sv_logsecret #{reservation.logsecret}; logaddress_add direct.#{SITE_HOST}:40001; servercfgfile reservation.cfg", allow_blocked: true)
        first_map = reservation.first_map.presence || "ctf_turbine"
        @server.rcon_exec("changelevel #{first_map}; exec reservation.cfg")
        reservation.status_update("Fast start attempted, waiting to boot")
      else
        reservation.status_update("Fast start failed, starting server normally")
        @server.clear_sdr_info!
        @server.restart
        reservation.status_update("Restarted server, waiting to boot")
      end
    end
  end

  sig { params(reservation: Reservation).void }
  def update_reservation(reservation)
    @server.update_configuration(reservation)
  end

  sig { params(reservation: Reservation).void }
  def end_reservation(reservation)
    reservation.reload
    return if reservation.ended?

    @server.remove_configuration
    download_stac_logs(reservation)
    @server.disable_plugins
    disable_demos_tf
    @server.restore_rgl_base_cfg
    @server.rcon_exec("sv_logflush 1; tv_stoprecord; kickall Reservation ended, every player can download the STV demo at https://#{SITE_HOST}")
    sleep 1 if Rails.env.production? # Give server a second to finish the STV demo and write the log

    if @server.uses_async_cleanup?
      @server.move_files_to_temp_directory(reservation)
    else
      zip_demos_and_logs(reservation)
      copy_logs(reservation)
      @server.remove_logs_and_demos
    end

    reservation.status_update("Restarting server")
    @server.rcon_disconnect
    @server.clear_sdr_info!
    @server.restart
    reservation.status_update("Restarted server")
  end

  sig { params(reservation: Reservation).void }
  def ensure_map_on_server(reservation)
    return if reservation.first_map.blank? || map_present?(T.must(reservation.first_map))

    reservation.status_update("Map #{reservation.first_map} not on the server, uploading")

    upload_map_to_server(reservation)
  end

  sig { params(map_name: String).returns(T.nilable(T::Boolean)) }
  def map_present?(map_name)
    @server.file_present?("#{@server.tf_dir}/maps/#{map_name}.bsp")
  end

  sig { params(reservation: Reservation).void }
  def upload_map_to_server(reservation)
    tempfile = Down.download("https://fastdl.serveme.tf/maps/#{reservation.first_map}.bsp")
    @server.copy_to_server([ tempfile.path ], "#{@server.tf_dir}/maps/#{reservation.first_map}.bsp")
    reservation.status_update("Uploaded map #{reservation.first_map} to server")
  end

  sig { params(reservation: Reservation).void }
  def download_stac_logs(reservation)
    # Cloud/SSH servers handle STAC logs in ReservationCleanupWorker
    # to avoid a race condition with server destruction
    return if @server.uses_async_cleanup?

    StacLogsDownloaderWorker.perform_async(reservation.id)
  end

  sig { void }
  def enable_demos_tf
    demos_tf_file = Rails.root.join("doc", "demostf.smx").to_s
    @server.copy_to_server([ demos_tf_file ], "#{@server.tf_dir}/addons/sourcemod/plugins")
  end

  sig { void }
  def disable_demos_tf
    @server.delete_from_server([ "#{@server.tf_dir}/addons/sourcemod/plugins/demostf.smx" ])
  end

  sig { params(reservation: Reservation).void }
  def zip_demos_and_logs(reservation)
    ZipFileCreator.create(reservation, @server.logs_and_demos)
  end

  sig { params(reservation: Reservation).void }
  def copy_logs(reservation)
    LogCopier.copy(reservation, @server)
  end
end
