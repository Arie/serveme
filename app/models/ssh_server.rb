class SshServer < Server

  def find_process_id
    execute("ps ux | grep port | grep #{port} | grep srcds_linux | grep -v grep | grep -v ruby | awk '{print \$2}'")
  end

  def remove_configuration
    [reservation_config_file, initial_map_config_file].each do |config_file|
      execute("rm -f #{config_file}")
    end
  end

  def remove_logs_and_demos
    execute("rm -f #{logs_and_demos.map(&:shellescape).join(' ')}")
  end

  def demos
    @demos ||= shell_output_to_array(execute("ls #{tf_dir}/*.dem"))
  end

  def logs
    @logs ||= shell_output_to_array(execute("ls #{tf_dir}/logs/*.log"))
  end

  def execute(command)
    logger.info "executing remotely: #{command}"
    ssh_exec(command).stdout
  end

  def ssh_exec(command)
    ssh.ssh(ip, command)
  end

  def copy_to_server(files, destination)
    scp(:scp_put, ip, files, destination)
  end

  def copy_from_server(files, destination)
    scp(:scp_get, ip, files, destination)
  end

  def scp(action, ip, files, destination)
    logger.info "SCP #{action}, FILES: #{files} DESTINATION: #{destination}"
    files.each do |file|
      ssh.send(action, ip, file.to_s, destination)
    end
  end

  def log_copier_class
    SshLogCopier
  end

  def zip_file_creator_class
    SshZipFileCreator
  end

  def write_configuration(output_filename, output_content)
    file = Tempfile.new('config_file')
    file.write(output_content)
    file.close
    upload_configuration(file.path, output_filename)
  end

  def kill_process
    execute("kill -15 #{process_id}")
  end

  def upload_configuration(configuration_file, upload_file)
    copy_to_server([configuration_file], upload_file)
  end

  def shell_output_to_array(shell_output)
    shell_output.lines.map(&:chomp)
  end

  def ssh
    @ssh ||= Net::SSH::Simple.new({:host_name => ip})
  end

end
