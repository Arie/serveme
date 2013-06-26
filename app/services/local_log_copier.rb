class LocalLogCopier < LogCopier

  def copy_logs
    FileUtils.cp(logs, directory_to_copy_to, :preserve => true)
  end

end
