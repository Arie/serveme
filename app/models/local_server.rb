# typed: true
# frozen_string_literal: true

class LocalServer < Server
  def remove_configuration
    delete_from_server(configuration_files)
  end

  def delete_from_server(files)
    files.each do |file|
      FileUtils.rm_rf(file)
    end
  end

  def restart
    if process_id
      logger.info "Killing process id #{process_id}"
      kill_process
    else
      logger.error "No process_id found for server #{id} - #{name}"
    end
  end

  def find_process_id
    # brakeman: ignore:Command Injection
    # port is validated and comes from the database
    `ps ux | grep port | grep #{port} | grep srcds_linux | grep -v grep | grep -v ruby | awk '{print \$2}'`
  end

  sig { returns(T::Array[String]) }
  def demos
    Dir.glob(demo_match)
  end

  sig { returns(T::Array[String]) }
  def logs
    Dir.glob(log_match)
  end

  sig { returns(T::Array[String]) }
  def stac_logs
    Dir.glob(stac_log_match)
  end
  sig { params(dir: String, pattern: String).returns(T::Array[String]) }
  def list_files(dir, pattern = "*")
    Dir.glob(File.join(tf_dir, dir, pattern)).map do |f|
      File.basename(f)
    end
  end

  def file_present?(file)
    system("ls #{file.shellescape}")
  end

  def copy_to_server(files, destination)
    # brakeman: ignore:Command Injection
    # files are escaped with shellescape and destination is controlled by the application
    system("cp #{files.map(&:shellescape).join(' ')} #{destination}")
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
    Process.kill(15, T.must(process_id))
  end

  def write_configuration(output_filename, output_content)
    File.write(output_filename, output_content)
  end
end
