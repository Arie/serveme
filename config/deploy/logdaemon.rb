Capistrano::Configuration.instance.load do
  namespace :logdaemon do
    def rails_env
      "RAILS_ENV=#{fetch(:rails_env, 'production')}"
    end

    def roles
      fetch(:logdaemon_server_role, :app)
    end

    def logdaemon_log
      fetch :logdaemon_log, 'log/logdaemon.log'
    end

    def logdaemon_pid
      fetch :logdaemon_pid, 'tmp/pids/logdaemon.pid'
    end

    def logdaemon_command
      fetch(:logdaemon_command, "script/logdaemon")
    end

    desc "Stop the logdaemon process"
    task :stop, :roles => lambda { roles } do
      run "cd #{current_path};#{rails_env} #{logdaemon_command} -k -P #{logdaemon_pid}"
    end

    desc "Start the logdaemon process"
    task :start, :roles => lambda { roles } do
      run "cd #{current_path};#{rails_env} #{logdaemon_command} -i #{main_server} -p 40002 -d -l #{logdaemon_log} -P #{logdaemon_pid}"
    end

    desc "Restart the logdaemon process"
    task :restart, :roles => lambda { roles } do
      stop
      start
    end
  end
end
