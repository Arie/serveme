# frozen_string_literal: true
class LocalLogCopier < LogCopier

  def copy_logs
    strip_command = %q|LANG=ALL LC_ALL=C sed -i -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/0.0.0.0/g'|
    strip_files   = logs.map(&:shellescape).join(' ')
    system("#{strip_command} #{strip_files}")
    system("cp #{logs.map(&:shellescape).join(" ")} #{directory_to_copy_to}")
  end

end
