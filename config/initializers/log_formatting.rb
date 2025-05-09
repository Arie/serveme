# typed: true
# frozen_string_literal: true

require "English"
module ActiveSupport
  class Logger
    class SimpleFormatter
      SEVERITY_TO_COLOR_MAP = { "DEBUG" => "0;37", "INFO" => "32", "WARN" => "33", "ERROR" => "31", "FATAL" => "31", "UNKNOWN" => "37" }.freeze

      def call(severity, time, _progname, msg)
        formatted_severity = format("%-5s", severity)

        formatted_time = time.strftime("%Y-%m-%d %H:%M:%S.") << time.usec.to_s[0..2].rjust(3)
        color = SEVERITY_TO_COLOR_MAP[severity]

        "\033[0;37m#{formatted_time}\033[0m [\033[#{color}m#{formatted_severity}\033[0m] #{msg.strip} (pid:#{$PROCESS_ID})\n"
      end
    end
  end
end
