require './config/boot'
require 'cronic/recipes'
require 'puma/capistrano'

set :stages,            %w(eu na)
set :default_stage,     "eu"
set :application,       "serveme"
set :deploy_to,         "/var/www/serveme"
set :use_sudo,          false
set :main_server,       "fakkelbrigade.eu"
set :keep_releases,     10
set :deploy_via,        :remote_cache
set :repository,        "https://github.com/Arie/serveme.git"
set :branch,            'master'
set :scm,               :git
set :copy_compression,  :gzip
set :use_sudo,          false
set :user,              'tf2'
set :rvm_ruby_string,   '2.1.0@serveme'
set :rvm_type,          :system
set :stage,             'production'
set :maintenance_template_path, 'app/views/pages/maintenance.html.erb'
set :deploy_to,         "/var/www/serveme"

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

after 'deploy:finalize_update', 'app:symlink'
after 'deploy',                 'deploy:cleanup'
after "deploy:stop",            "cronic:stop"
after "deploy:start",           "cronic:start"
after "deploy:restart",         "cronic:restart"

namespace :app do
  desc "makes a symbolic link to the shared files"
  task :symlink, :roles => [:web, :app] do
    run "ln -sf #{shared_path}/steam_api_key.rb #{release_path}/config/initializers/steam_api_key.rb"
    run "ln -sf #{shared_path}/database.yml #{release_path}/config/database.yml"
    run "ln -sf #{shared_path}/paypal.yml #{release_path}/config/paypal.yml"
    run "ln -sf #{shared_path}/uploads #{release_path}/public/uploads"
    run "ln -sf #{shared_path}/server_logs #{release_path}/server_logs"
    run "ln -sf #{shared_path}/raven.rb #{release_path}/config/initializers/raven.rb"
    run "ln -sf #{shared_path}/logs_tf_api_key.rb #{release_path}/config/initializers/logs_tf_api_key.rb"
    run "ln -sf #{shared_path}/maps_dir.rb #{release_path}/config/initializers/maps_dir.rb"
    run "ln -sf #{shared_path}/secret_token.rb #{release_path}/config/initializers/secret_token.rb"
    run "ln -sf #{shared_path}/locale.rb #{release_path}/config/initializers/locale.rb"
    run "ln -sf #{shared_path}/devise.rb #{release_path}/config/initializers/devise.rb"
    run "ln -sf #{shared_path}/site_url.rb #{release_path}/config/initializers/site_url.rb"
  end

end

namespace :puma do
    desc 'Start puma'
    task :start, :roles => lambda { fetch(:puma_role) }, :on_no_matching_servers => :continue do
      puma_env = fetch(:rack_env, fetch(:rails_env, 'production'))
      run "cd #{current_path} && #{fetch(:puma_cmd)} -q -d #{fetch(:puma_flags)} -e #{puma_env} -b '#{fetch(:puma_socket)}' -S #{fetch(:puma_state)} --control 'unix://#{shared_path}/sockets/pumactl.sock'", :pty => false
    end
end

def execute_rake(task_name, path = release_path)
  run "cd #{path} && bundle exec rake RAILS_ENV=#{rails_env} #{task_name}", :env => {'RAILS_ENV' => rails_env}
end

after "deploy", "deploy:cleanup"

require 'rvm/capistrano'
