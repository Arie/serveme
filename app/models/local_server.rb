# typed: true
# frozen_string_literal: true

class LocalServer < Server
  extend T::Sig
  sig { returns(T.nilable(T::Boolean)) }
  def remove_configuration
    delete_from_server(configuration_files)
  end

  sig { params(files: T::Array[String]).returns(T.nilable(T::Boolean)) }
  def delete_from_server(files)
    files.each do |file|
      FileUtils.rm_rf(file)
    end
    true
  end

  sig { returns(T.nilable(T.any(String, T::Boolean))) }
  def restart
    if process_id
      logger.info "Killing process id #{process_id}"
      kill_process
      true
    else
      logger.error "No process_id found for server #{id} - #{name}"
      false
    end
  end

  sig { returns(T.nilable(String)) }
  def find_process_id
    # brakeman: ignore:Command Injection
    # port is validated and comes from the database
    process_name = team_comtress_server? ? "srcds_run_64" : "srcds_linux"
    `ps ux | grep port | grep #{port} | grep #{process_name} | grep -v grep | grep -v ruby | awk '{print \$2}'`
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

  sig { params(file: String).returns(T.nilable(T::Boolean)) }
  def file_present?(file)
    system("ls #{file.shellescape}")
  end

  sig { params(files: T::Array[String], destination: String).returns(T.nilable(T::Boolean)) }
  def copy_to_server(files, destination)
    # brakeman: ignore:Command Injection
    # files are escaped with shellescape and destination is controlled by the application
    system("cp #{files.map(&:shellescape).join(' ')} #{destination}")
  end

  sig { returns(T.nilable(T.any(String, T::Boolean))) }
  def remove_logs_and_demos
    FileUtils.rm(logs + demos)
    true
  end

  sig { returns(T.class_of(LocalLogCopier)) }
  def log_copier_class
    LocalLogCopier
  end

  sig { returns(T.class_of(LocalZipFileCreator)) }
  def zip_file_creator_class
    LocalZipFileCreator
  end

  private

  sig { void }
  def kill_process
    Process.kill(15, T.must(process_id))
  end

  sig { params(output_filename: String, output_content: String).returns(T.nilable(T::Boolean)) }
  def write_configuration(output_filename, output_content)
    dir = File.dirname(output_filename)
    FileUtils.mkdir_p(dir) unless File.directory?(dir)
    File.write(output_filename, output_content)
    true
  end
end
