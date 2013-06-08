class LocalServer < Server

  def remove_configuration
    [reservation_config_file, initial_map_config_file].each do |config_file|
      if File.exists?(config_file)
        File.delete(config_file)
      end
    end
  end

  def find_process_id
    all_processes   = Sys::ProcTable.ps
    found_processes = all_processes.select {|process| process.cmdline.match(/#{port}/) && process.cmdline.match(/\.\/srcds_linux/) && !process.cmdline.match(/\.\/tv_relay/) }
    if found_processes.any?
      found_processes.first.pid
    end
  end

  def demos
    Dir.glob(demo_match)
  end

  def logs
    Dir.glob(log_match)
  end

  def remove_logs_and_demos
    FileUtils.rm(logs + demos)
  end

  def log_copier_class
    LocalLogCopier
  end

  def zip_file_creator_class
    LocalZipFileCreator
  end

  private

  def kill_process
    Process.kill(15, process_id)
  end

  def write_configuration(output_filename, output_content)
    File.open(output_filename, 'w') do |f|
      f.write(output_content)
    end
  end

end
