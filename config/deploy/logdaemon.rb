# typed: false
# frozen_string_literal: true

namespace :logdaemon do
  define_method(:logdaemon_log) do ||
    fetch :logdaemon_log, "log/logdaemon.log"
  end

  define_method(:logdaemon_pid) do ||
    fetch :logdaemon_pid, "tmp/pids/logdaemon.pid"
  end

  define_method(:logdaemon_command) do ||
    fetch(:logdaemon_command, "script/logdaemon")
  end

  define_method(:logdaemon_host) do ||
    fetch(:logdaemon_host, fetch(:main_server))
  end

  desc "Stop the logdaemon process"
  task :stop do
    on roles(:web, :app) do
      within current_path do
        execute :ruby, "#{logdaemon_command} -k -P #{logdaemon_pid}"
      end
    end
  end

  desc "Start the logdaemon process"
  task :start do
    on roles(:web, :app) do
      within current_path do
        execute :ruby, "#{logdaemon_command} -i #{logdaemon_host} -p 40001 -d -l #{logdaemon_log} -P #{logdaemon_pid}"
      end
    end
  end

  desc "Restart the logdaemon process"
  task :restart do
    on roles(:web, :app) do
      within current_path do
        execute :ruby, "#{logdaemon_command} -k -P #{logdaemon_pid}"
        execute :ruby, "#{logdaemon_command} -i #{logdaemon_host} -p 40001 -d -l #{logdaemon_log} -P #{logdaemon_pid}"
      end
    end
  end
end
