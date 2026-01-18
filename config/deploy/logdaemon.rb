# typed: false
# frozen_string_literal: true

namespace :logdaemon do
  define_method(:logdaemon_service_name) do
    "serveme_logdaemon_#{fetch(:stage)}"
  end

  define_method(:logdaemon_socket_name) do
    "#{logdaemon_service_name}.socket"
  end

  define_method(:logdaemon_host) do
    # systemd ListenDatagram requires IP address, not hostname
    fetch(:logdaemon_host, "0.0.0.0")
  end

  define_method(:logdaemon_port) do
    fetch(:logdaemon_port, 40001)
  end

  define_method(:systemd_user_dir) do
    ".config/systemd/user"
  end

  desc "Setup systemd units for logdaemon"
  task :setup do
    on roles(:web, :app) do
      execute :mkdir, "-p", systemd_user_dir
      execute :mkdir, "-p", "#{systemd_user_dir}/sockets.target.wants"
      execute :mkdir, "-p", "#{systemd_user_dir}/default.target.wants"

      socket_unit = <<~SOCKET
        [Unit]
        Description=TF2 Log Daemon UDP Socket for serveme (#{fetch(:stage)})

        [Socket]
        ListenDatagram=#{logdaemon_host}:#{logdaemon_port}

        # Increase receive buffer to handle bursts during restarts
        ReceiveBuffer=16M

        # Allow socket reuse for seamless restarts
        ReusePort=true

        SyslogIdentifier=#{logdaemon_service_name}_socket

        [Install]
        WantedBy=sockets.target
      SOCKET

      home_dir = capture(:echo, "$HOME").strip
      rvm_path = "#{home_dir}/.rvm"

      service_unit = <<~SERVICE
        [Unit]
        Description=TF2 Log Daemon for serveme (#{fetch(:stage)})
        Requires=#{logdaemon_socket_name}
        After=syslog.target network.target

        [Service]
        Type=simple
        WorkingDirectory=#{current_path}
        ExecStart=#{rvm_path}/bin/rvm default do ruby script/logdaemon

        RestartSec=1
        Restart=on-failure

        StandardOutput=append:#{shared_path}/log/logdaemon.log
        StandardError=append:#{shared_path}/log/logdaemon.error.log

        SyslogIdentifier=#{logdaemon_service_name}

        [Install]
        WantedBy=default.target
      SERVICE

      # Upload unit files
      upload! StringIO.new(socket_unit), "#{systemd_user_dir}/#{logdaemon_socket_name}"
      upload! StringIO.new(service_unit), "#{systemd_user_dir}/#{logdaemon_service_name}.service"

      # Reload systemd and enable units
      execute :systemctl, "--user", "daemon-reload"
      execute :systemctl, "--user", "enable", logdaemon_socket_name
      execute :systemctl, "--user", "enable", "#{logdaemon_service_name}.service"

      info "Logdaemon systemd units installed. Start with: cap #{fetch(:stage)} logdaemon:start"
    end
  end

  desc "Stop the logdaemon process"
  task :stop do
    on roles(:web, :app) do
      execute :systemctl, "--user", "stop", "#{logdaemon_service_name}.service"
    end
  end

  desc "Start the logdaemon socket and service"
  task :start do
    on roles(:web, :app) do
      execute :systemctl, "--user", "start", logdaemon_socket_name
      execute :systemctl, "--user", "start", "#{logdaemon_service_name}.service"
    end
  end

  desc "Restart the logdaemon process (socket stays open)"
  task :restart do
    on roles(:web, :app) do
      # Ensure socket is running (holds the port open during restart)
      execute :systemctl, "--user", "start", logdaemon_socket_name
      # Restart only the service, not the socket
      execute :systemctl, "--user", "restart", "#{logdaemon_service_name}.service"
    end
  end

  desc "Show logdaemon status"
  task :status do
    on roles(:web, :app) do
      execute :systemctl, "--user", "status", logdaemon_socket_name, raise_on_non_zero_exit: false
      execute :systemctl, "--user", "status", "#{logdaemon_service_name}.service", raise_on_non_zero_exit: false
    end
  end

  desc "View logdaemon logs"
  task :logs do
    on roles(:web, :app) do
      execute :journalctl, "--user", "-u", "#{logdaemon_service_name}.service", "-n", "100", "--no-pager"
    end
  end

  desc "Remove old Dante-based logdaemon (migration helper)"
  task :cleanup_dante do
    on roles(:web, :app) do
      within current_path do
        # Kill old dante process if running
        old_pid_file = "#{shared_path}/tmp/pids/logdaemon.pid"
        if test("[ -f #{old_pid_file} ]")
          old_pid = capture(:cat, old_pid_file).strip
          if test("kill -0 #{old_pid} 2>/dev/null")
            execute :kill, old_pid
            info "Killed old Dante logdaemon process (PID: #{old_pid})"
          end
          execute :rm, "-f", old_pid_file
        end
      end
    end
  end
end
