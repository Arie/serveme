namespace :logdaemon do
  def logdaemon_log
    fetch :logdaemon_log, 'log/logdaemon.log'
  end

  def logdaemon_pid
    fetch :logdaemon_pid, 'tmp/pids/logdaemon.pid'
  end

  def logdaemon_command
    fetch(:logdaemon_command, "script/logdaemon")
  end

  def logdaemon_host
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
