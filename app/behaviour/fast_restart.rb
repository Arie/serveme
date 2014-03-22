module FastRestart

  def restart(rcon = current_rcon)
    begin
      fast_restart(rcon)
    rescue Exception => e
      Rails.logger.warn("Got error #{e.class}: #{e.message} trying to do a fast restart of server #{name}, falling back to slow restart")
      slow_restart
    end
  end

  def fast_restart(rcon = current_rcon)
    Rails.logger.info("Attempting RCON changelevel restart of server #{name}")
    if rcon_auth(rcon)
      status = condenser.rcon_exec("status")
      unless status.include?("hostname:")
        raise Exception, "RCON status didn't seem correct: #{status}"
      end
      rcon_exec("kickall; tftrue_tv_delaymapchange 0; changelevel ctf_turbine")
    else
      raise Exception, "Couldn't RCON auth to the server"
    end
  end

end
