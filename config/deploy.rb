# frozen_string_literal: true
require './config/deploy/logdaemon'
# config valid only for current version of Capistrano
lock '3.8.0'

set :application,       'serveme'
set :repo_url,          'https://github.com/Arie/serveme.git'
set :deploy_to,         '/var/www/serveme'
set :copy_compression,  :gzip
set :use_sudo,          false
set :user,              'tf2'
set :rvm_ruby_string,   '2.3.0'
set :rvm_type,          :system

set :maintenance_template_path, 'app/views/pages/maintenance.html.erb'

# Rails
set :rails_env, 'production'
set :conditionally_migrate, true

# Puma
set :puma_conf,         "#{release_path}/config/puma/production.rb"
set :puma_state,        "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,          "#{shared_path}/tmp/pids/puma.pid"
set :puma_bind,         "unix://#{shared_path}/tmp/sockets/puma.sock" # accept array for multi-bind
set :puma_default_control_app, "unix://#{shared_path}/tmp/sockets/pumactl.sock"
set :puma_access_log, fetch(:rack_env, fetch(:rails_env, 'production'))
set :puma_init_active_record, true
set :puma_preload_app, false

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/puma/production.rb', 'config/initializers/locale.rb', 'config/initializers/steam_api_key.rb', 'config/paypal.yml', 'config/stripe.yml', 'config/initializers/raven.rb', 'config/initializers/logs_tf_api_key.rb', 'config/initializers/demos_tf_api_key.rb', 'config/initializers/maps_dir.rb', 'config/initializers/secret_token.rb', 'config/initializers/devise.rb', 'config/initializers/site_url.rb', 'doc/GeoLiteCity.dat', 'config/cacert.pem')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/uploads', 'public/system', 'server_logs')

after 'deploy:finishing', 'logdaemon:restart'
