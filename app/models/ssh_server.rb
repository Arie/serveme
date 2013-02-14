class SshServer < Server

  def remove_configuration
    execute("rm -f #{reservation_config_file}")
  end

  def find_process_id
    execute("ps ux | grep port | grep #{port} | grep srcds_linux | grep -v grep | grep -v ruby | awk '{print \\$2}'")
  end

  def demos
    @demos ||= shell_output_to_array(execute("ls #{tf_dir}/*.dem"))
  end

  def logs
    @logs ||= shell_output_to_array(execute("ls #{tf_dir}/logs/L*.log"))
  end

  def remove_logs_and_demos
    execute("rm -f #{logs_and_demos.join(' ')}")
  end

  def execute(command)
    ssh_command = "ssh #{ip} \"#{command}\""
    logger.info "executing remotely: #{ssh_command}"
    `#{ssh_command}`
  end

  def copy_to_server(files, destination)
    copy_command = "scp #{files} #{ip}:#{destination}"
    logger.info "copying to remote server: #{copy_command}"
    `#{copy_command}`
  end

  def copy_from_server(files, destination)
    copy_command = "scp #{ip}:#{files} #{destination}"
    logger.info "copying from remote server: #{copy_command}"
    `#{copy_command}`
  end

  def log_copier_class
    SshLogCopier
  end

  def zip_file_creator_class
    SshZipFileCreator
  end

  private

  def kill_process
    execute("kill -15 #{process_id}")
  end

  def write_configuration(output_filename, output_content)
    tmp_file = Rails.root.join("tmp", "server_#{id}_reservation.cfg")
    File.open(tmp_file, "w") do |f|
      f.write(output_content)
    end
    copy_to_server(tmp_file, reservation_config_file)
  end

  def shell_output_to_array(shell_output)
    shell_output.lines.map(&:chomp)
  end

end
