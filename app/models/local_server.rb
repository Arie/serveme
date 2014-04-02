class LocalServer < Server

  def remove_configuration
    [reservation_config_file, initial_map_config_file].each do |config_file|
      if File.exists?(config_file)
        File.delete(config_file)
      end
    end
  end

  unless defined? JRUBY_VERSION
    def find_process_id
      all_processes   = Sys::ProcTable.ps
      found_processes = all_processes.select {|process| process.cmdline.match(/#{port}/) && process.cmdline.match(/\.\/srcds_linux/) && !process.cmdline.match(/\.\/tv_relay/) }
      if found_processes.any?
        found_processes.first.pid
      end
    end
  else
    def find_process_id
      @process_id ||= begin
                        pid = `ps ux | grep 'port #{port}' | grep 'srcds_linux' | grep -v grep | grep -v ruby | awk '{print $2}'`.to_i if pid > 0
                        pid
                      end
    end
  end

  def demos
    Dir.glob(demo_match)
  end

  def logs
    Dir.glob(log_match)
  end

  def list_files(dir)
    Dir.glob(File.join(tf_dir, dir, "*"))
  end

  def copy_to_server(files, destination)
    FileUtils.cp(files, destination)
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
