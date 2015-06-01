class LogCopier

  attr_accessor :reservation, :server, :logs

  def initialize(reservation, server)
    @server           = server
    @reservation      = reservation
    @logs             = server.logs
  end

  def self.copy(reservation, server)
    reservation.status_update("Getting logs from server")
    server.log_copier_class.new(reservation, server).copy
  end

  def copy
    make_directory
    set_directory_permissions
    copy_logs
  end

  def directory_to_copy_to
    Rails.root.join("server_logs", "#{reservation.id}")
  end

  def make_directory
    FileUtils.mkdir_p(directory_to_copy_to)
  end

  def set_directory_permissions
    FileUtils.chmod_R(0775, directory_to_copy_to)
  end

end
