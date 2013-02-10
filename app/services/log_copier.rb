class LogCopier

  attr_accessor :reservation_id, :logs

  def initialize(reservation_id, logs)
    @reservation_id = reservation_id
    @logs = logs
  end

  def copy
    make_directory
    copy_logs
  end

  private

  def make_directory
    FileUtils.mkdir_p(directory_to_copy_to)
  end

  def copy_logs
    FileUtils.cp(logs, directory_to_copy_to, :preserve => true)
  end

  def directory_to_copy_to
    Rails.root.join("server_logs", "#{reservation_id}")
  end

end
