# typed: true
# frozen_string_literal: true

class LocalLogCopier < LogCopier
  def copy_logs
    system("LANG=ALL", "LC_ALL=C", "sed", "-i", "-r", 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/0.0.0.0/g', *logs)
    system("cp", *logs, directory_to_copy_to.to_s)
  end
end
