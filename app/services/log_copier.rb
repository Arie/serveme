class LogCopier

  attr_accessor :reservation_id, :server, :logs

  def initialize(reservation_id, server)
    @server           = server
    @reservation_id   = reservation_id
    @logs             = server.logs
  end

  def self.copy(reservation_id, server)
    server.log_copier_class.new(reservation_id, server).copy
  end

  def copy
    make_directory
    copy_logs
  end

  def directory_to_copy_to
    Rails.root.join("server_logs", "#{reservation_id}")
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
    server.copy_from_server(logs.join(" "), directory_to_copy_to)
  end

end
