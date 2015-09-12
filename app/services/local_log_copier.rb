class LocalLogCopier < LogCopier

  def copy_logs
    system("cp #{logs.map(&:shellescape).join(" ")} #{directory_to_copy_to}")
  end

end
