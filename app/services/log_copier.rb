class LogCopier

  attr_accessor :reservation, :server, :logs

  def initialize(reservation, server)
    @server           = server
    @reservation      = reservation
    @logs             = server.logs
  end

  def self.copy(reservation, server)
    server.log_copier_class.new(reservation, server).copy
  end

  def copy
    make_directory
    copy_logs
  end

  def directory_to_copy_to
    Rails.root.join("server_logs", "#{reservation.id}")
  end

  def make_directory
    FileUtils.mkdir_p(directory_to_copy_to)
  end

end

class LocalLogCopier < LogCopier

  def copy_logs
    FileUtils.cp(logs, directory_to_copy_to, :preserve => true)
  end

end

class SshLogCopier < LogCopier

  def copy_logs
    zipfile_name_and_path = Rails.root.join("public", "uploads", reservation.zipfile_name)
    Zip::ZipFile.foreach(zipfile_name_and_path) do |zipped_file|
      if zipped_file.name.match("^.*\.log$")
        zipped_file.extract(File.join(directory_to_copy_to, zipped_file.name)) { true }
      end
    end
  end

end
