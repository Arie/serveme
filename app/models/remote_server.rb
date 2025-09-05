# typed: true
# frozen_string_literal: true

class RemoteServer < Server
  extend T::Sig
  sig { params(output_filename: String, output_content: String).returns(T.nilable(T::Boolean)) }
  def write_configuration(output_filename, output_content)
    file = Tempfile.new("config_file")
    file.sync = true
    file.write(output_content)
    upload_configuration(T.must(file.path), output_filename)
  ensure
    T.must(file).close
    T.must(file).unlink
  end

  sig { params(configuration_file: String, upload_file: String).returns(T.nilable(T::Boolean)) }
  def upload_configuration(configuration_file, upload_file)
    copy_to_server([ configuration_file ], upload_file)
  end

  sig { returns(T.nilable(T.any(String, T::Boolean))) }
  def remove_configuration
    delete_from_server(configuration_files)
  end

  sig { returns(T.nilable(T.any(String, T::Boolean))) }
  def remove_logs_and_demos
    delete_from_server(logs_and_demos)
  end

  sig { returns(T.class_of(RemoteLogCopier)) }
  def log_copier_class
    RemoteLogCopier
  end
end
