# typed: true
# frozen_string_literal: true

class SshServer < RemoteServer
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def find_process_id
    process_name = team_comtress_server? ? "tc2_linux64 | grep -v srcds_run_64 | grep -v steam-runtime-tools" : "srcds_linux"
    execute("ps ux | grep port | grep #{port} | grep #{process_name} | grep -v grep | grep -v ruby | awk '{print $2}'")
  end

  sig { returns(T::Array[String]) }
  def demos
    @demos ||= shell_output_to_array(execute("ls #{tf_dir}/*.dem")) || []
  end

  sig { returns(T::Array[String]) }
  def logs
    @logs ||= shell_output_to_array(execute("ls #{tf_dir}/logs/*.log")) || []
  end

  sig { returns(T::Array[String]) }
  def stac_logs
    @stac_logs ||= shell_output_to_array(execute("ls #{tf_dir}/addons/sourcemod/logs/stac/*.log")) || []
  end

  sig { params(dir: String).returns(T::Array[String]) }
  def list_files(dir)
    files = []
    Net::SFTP.start(ip, nil) do |sftp|
      sftp.dir.foreach(File.join(tf_dir, dir)) do |entry|
        files << entry.name
      end
    end
    files
  end

  sig { params(file: String).returns(T.nilable(T::Boolean)) }
  def file_present?(file)
    Net::SFTP.start(ip, nil) do |sftp|
      return !!sftp.lstat!(file)
    end
  rescue Net::SFTP::StatusException => e
    return false if e.code == 2

    raise
  end

  sig { params(files: T::Array[String]).returns(T.nilable(T::Boolean)) }
  def delete_from_server(files)
    result = execute("rm -f #{files.map(&:shellescape).join(' ')}")
    !!result
  end

  sig { params(command: String, log: T::Boolean).returns(T.nilable(String)) }
  def execute(command, log: true)
    logger.info "executing remotely: #{command}" if log
    ssh_exec(command)
  end

  sig { params(command: String, log_stderr: T::Boolean).returns(String) }
  def ssh_exec(command, log_stderr: false)
    out = []
    err = []
    ssh&.exec!(command) do |_channel, stream, data|
      out << data if stream == :stdout
      err << data if stream == :stderr
    end
    logger.info "SSH STDERR while executing #{command}:\n#{err.join("\n")}" if log_stderr && err.any?
    out.join("\n")
  end

  sig { params(command: String).returns(T::Hash[Symbol, T.untyped]) }
  def execute_with_status(command)
    logger.info "executing remotely with status check: #{command}"

    wrapped_command = "#{command} && echo '__CMD_SUCCESS__' || echo '__CMD_FAILURE__'"
    out = []
    err = []

    ssh&.exec!(wrapped_command) do |_channel, stream, data|
      out << data if stream == :stdout
      err << data if stream == :stderr
    end

    stdout_text = out.join("\n")
    stderr_text = err.join("\n")
    success = stdout_text.include?("__CMD_SUCCESS__")

    stdout_text = stdout_text.gsub(/\n?__CMD_(SUCCESS|FAILURE)__\n?/, "")

    {
      stdout: stdout_text,
      stderr: stderr_text,
      success: success
    }
  end

  sig { params(files: T::Array[String], destination: String).returns(T.nilable(T::Boolean)) }
  def copy_to_server(files, destination)
    # brakeman: ignore:Command Injection
    # files are escaped with shellescape, ip is validated, and destination is controlled by the application
    logger.debug "SCP PUT, FILES: #{files} DESTINATION: #{destination}"
    system("#{scp_command} #{files.map(&:shellescape).join(' ')} #{ip}:#{destination}")
  end

  sig { params(files: T::Array[String], destination: String).returns(T.nilable(T::Boolean)) }
  def copy_from_server(files, destination)
    # brakeman: ignore:Command Injection
    # files are escaped with shellescape, ip is validated, and destination is controlled by the application
    logger.debug "SCP GET, FILES: #{files.join(', ')} DESTINATION: #{destination}"
    system("#{scp_command} #{ip}:\"#{files.map(&:shellescape).join(' ')}\" #{destination}")
  end

  sig { returns(T.class_of(DownloadThenZipFileCreator)) }
  def zip_file_creator_class
    DownloadThenZipFileCreator
  end

  sig { returns(T.nilable(String)) }
  def kill_process
    execute("kill -15 #{process_id}")
  end

  sig { returns(T.nilable(String)) }
  def restart
    if process_id
      logger.info "Killing process id #{process_id}"
      kill_process
    else
      logger.error "No process_id found for server #{id} - #{name}"
    end
    ssh_close
    nil
  end

  sig { params(shell_output: T.nilable(String)).returns(T.nilable(T::Array[String])) }
  def shell_output_to_array(shell_output)
    return nil if shell_output.nil?

    shell_output.lines.map(&:chomp)
  end

  sig { returns(T.nilable(Net::SSH::Connection::Session)) }
  def ssh
    @ssh ||= Net::SSH.start(ip, nil)
  end

  sig { void }
  def ssh_close
    ssh.try(:close)
    @ssh = nil
  end

  sig { returns(T::Boolean) }
  def supports_mitigations?
    true
  end

  sig { params(reservation: Reservation).returns(String) }
  def temp_directory_for_reservation(reservation)
    "#{tf_dir}/temp_reservation_#{reservation.id}"
  end

  sig { params(reservation: Reservation).void }
  def move_files_to_temp_directory(reservation)
    temp_dir = temp_directory_for_reservation(reservation)

    mkdir_result = execute_with_status("mkdir -p #{temp_dir.shellescape}")
    unless mkdir_result[:success]
      error_msg = "Failed to create temp directory on remote server: #{mkdir_result[:stderr]}"
      logger.error error_msg
      reservation.status_update(error_msg)
      raise StandardError, error_msg
    end

    files_to_move = logs + demos
    return if files_to_move.empty?

    escaped_files = files_to_move.map(&:shellescape).join(" ")
    move_result = execute_with_status("mv -t #{temp_dir.shellescape} #{escaped_files}")

    unless move_result[:success]
      error_msg = "Failed to move files to temp directory on remote server: #{move_result[:stderr]}"
      logger.error error_msg
      reservation.status_update(error_msg)
      raise StandardError, error_msg
    end
  end

  sig { returns(T::Boolean) }
  def uses_async_cleanup?
    true
  end

  private

  sig { returns(String) }
  def scp_command
    "scp -O -T -l 200000"
  end
end
