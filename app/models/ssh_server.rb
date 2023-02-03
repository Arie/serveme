# frozen_string_literal: true

class SshServer < RemoteServer
  def find_process_id
    execute("ps ux | grep port | grep #{port} | grep srcds_linux | grep -v grep | grep -v ruby | awk '{print $2}'")
  end

  def demos
    @demos ||= shell_output_to_array(execute("ls #{tf_dir}/*.dem"))
  end

  def logs
    @logs ||= shell_output_to_array(execute("ls #{tf_dir}/logs/*.log"))
  end

  def list_files(dir)
    files = []
    Net::SFTP.start(ip, nil) do |sftp|
      sftp.dir.foreach(File.join(tf_dir, dir)) do |entry|
        files << entry.name
      end
    end
    files
  end

  def delete_from_server(files)
    execute("rm -f #{files.map(&:shellescape).join(' ')}")
  end

  def execute(command, log: true)
    logger.info "executing remotely: #{command}" if log
    ssh_exec(command)
  end

  def ssh_exec(command, log_stderr: false)
    out = []
    err = []
    ssh.exec!(command) do |_channel, stream, data|
      out << data if stream == :stdout
      err << data if stream == :stderr
    end
    logger.info "SSH STDERR while executing #{command}:\n#{err.join("\n")}" if log_stderr && err.any?
    out.join("\n")
  end

  def copy_to_server(files, destination)
    logger.debug "SCP PUT, FILES: #{files} DESTINATION: #{destination}"
    system("#{scp_command} #{files.map(&:shellescape).join(' ')} #{ip}:#{destination}")
  end

  def copy_from_server(files, destination)
    logger.debug "SCP GET, FILES: #{files.join(', ')} DESTINATION: #{destination}"
    system("#{scp_command} #{ip}:\"#{files.map(&:shellescape).join(' ')}\" #{destination}")
  end

  def zip_file_creator_class
    DownloadThenZipFileCreator
  end

  def kill_process
    execute("kill -15 #{process_id}")
  end

  def restart
    if process_id
      logger.info "Killing process id #{process_id}"
      kill_process
    else
      logger.error "No process_id found for server #{id} - #{name}"
    end
    ssh_close
  end

  def shell_output_to_array(shell_output)
    shell_output.lines.to_a.map(&:chomp)
  end

  def ssh
    @ssh ||= Net::SSH.start(ip, nil)
  end

  def ssh_close
    ssh.try(:close)
    @ssh = nil
  end

  def supports_mitigations?
    SITE_HOST != 'sea.serveme.tf'
  end

  private

  def scp_command
    'scp -T'
  end
end
