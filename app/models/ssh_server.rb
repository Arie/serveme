class SshServer < RemoteServer

  def find_process_id
    execute("ps ux | grep port | grep #{port} | grep srcds_linux | grep -v grep | grep -v ruby | awk '{print \$2}'")
  end

  def demos
    @demos ||= shell_output_to_array(execute("ls #{tf_dir}/*.dem"))
  end

  def logs
    @logs ||= shell_output_to_array(execute("ls #{tf_dir}/logs/*.log"))
  end

  def delete_from_server(files)
    execute("rm -f #{files.map(&:shellescape).join(' ')}")
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
    if File.directory?(destination)
      destination_dir = destination
      destination_is_directory = true
    else
      destination_is_directory = false
    end
    Net::SFTP.start(ip, nil) do |sftp|
      files.collect do |file|
        if destination_is_directory
          destination = File.join(destination_dir, File.basename(file))
        end
        sftp.download(file, File.new(destination, 'wb'))
      end
    end
  end

  def scp(action, ip, files, destination)
    logger.info "SCP #{action}, FILES: #{files} DESTINATION: #{destination}"
    files.each do |file|
      ssh.send(action, ip, file.to_s, destination)
    end
  end

  def zip_file_creator_class
    SshZipFileCreator
  end

  def kill_process
    execute("kill -15 #{process_id}")
  end

  def shell_output_to_array(shell_output)
    shell_output.lines.map(&:chomp)
  end

  def ssh
    @ssh ||= Net::SSH::Simple.new({:host_name => ip})
  end

end
