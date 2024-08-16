# typed: false
# frozen_string_literal: true

class RemoteServer < Server
  def write_configuration(output_filename, output_content)
    file = Tempfile.new('config_file')
    file.sync = true
    file.write(output_content)
    upload_configuration(file.path, output_filename)
  ensure
    file.close
    file.unlink
  end

  def upload_configuration(configuration_file, upload_file)
    copy_to_server([configuration_file], upload_file)
  end

  def remove_configuration
    delete_from_server(configuration_files)
  end

  def remove_logs_and_demos
    delete_from_server(logs_and_demos)
  end

  def log_copier_class
    RemoteLogCopier
  end
end
