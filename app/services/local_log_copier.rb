# typed: true
# frozen_string_literal: true

require "open3"

class LocalLogCopier < LogCopier
  def copy_logs
    _, stderr, status = T.unsafe(Open3).capture3("LANG=ALL", "LC_ALL=C", "sed", "-i", "-r", 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/0.0.0.0/g', *logs)
    Rails.logger.error("Failed to strip IPs from logs: #{stderr}") unless status.success?

    _, stderr, status = T.unsafe(Open3).capture3("cp", *logs, directory_to_copy_to.to_s)
    Rails.logger.error("Failed to copy logs: #{stderr}") unless status.success?
  end
end
