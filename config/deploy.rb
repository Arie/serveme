# typed: false
# frozen_string_literal: true

require "./config/deploy/logdaemon"

set :application,       "serveme"
set :repo_url,          "https://github.com/Arie/serveme.git"
set :deploy_to,         "/var/www/serveme"
set :copy_compression,  :gzip
set :use_sudo,          false
set :user,              "tf2"
set :rvm_ruby_string,   "ruby-4.0.0"
set :rvm_type,          :system
set :pty,               true

set :maintenance_template_path, "app/views/pages/maintenance.html.erb"

# Rails
set :conditionally_migrate, true
set :rails_env, "production"
set :default_env, { "RAILS_ENV" => "production" }

# Puma
set :puma_conf,         "#{release_path}/config/puma/production.rb"
set :puma_state,        "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,          "#{shared_path}/tmp/pids/puma.pid"
set :puma_bind,         "unix://#{shared_path}/tmp/sockets/puma.sock" # accept array for multi-bind
set :puma_default_control_app, "unix://#{shared_path}/tmp/sockets/pumactl.sock"
set :puma_access_log, fetch(:rack_env, fetch(:rails_env, "production"))
set :puma_init_active_record, true
set :puma_preload_app, false
set :puma_phased_restart, true
set :puma_enable_socket_service, true

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push("config/master.key", "config/credentials/production.key", "config/database.yml", "config/puma/production.rb", "config/initializers/locale.rb", "config/initializers/maps_dir.rb", "config/initializers/01_site_url.rb", "doc/GeoLite2-City.mmdb", "doc/GeoLite2-ASN.mmdb", "config/cacert.pem")

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push("log", "tmp/pids", "tmp/cache", "tmp/sockets", "vendor/bundle", "public/uploads", "public/system", "server_logs")

# Configure asset dependencies for faster_assets
set :assets_dependencies, %w[app/assets app/javascript lib/assets vendor/assets Gemfile.lock config/routes.rb]

after "deploy:finishing", "logdaemon:restart"

namespace :discord_bot do
  desc "Restart Discord bot"
  task :restart do
    on roles(:app) do
      execute "systemctl --user restart serveme-discord-bot"
    end
  end
end

after "deploy:published", "discord_bot:restart"
