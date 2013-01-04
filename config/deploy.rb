require './config/boot'
require 'rvm/capistrano'

set :application,       "serveme"
set :deploy_to,         "/var/www/serveme"
set :use_sudo,          false
set :main_server,       "fakkelbrigade.eu"
set :keep_releases,     10
set :deploy_via,        :copy
set :repository,        "https://github.com/Arie/serveme.git"
set :branch,            'reservations'
set :scm,               :git
set :copy_compression,  :gzip
set :use_sudo,          false
set :user,              'tf2'
set :rvm_ruby_string,   '1.9.3@serveme'
set :rvm_type,          :system

server "#{main_server}", :web, :app, :db, :primary => true

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

after 'deploy:finalize_update', 'app:symlink'
after 'deploy',                 'deploy:cleanup'

namespace :deploy do
  desc "Restart the servers"
  task :restart do
    run "cd #{release_path}; bundle exec thin -C config/thin.yml stop"
    run "cd #{release_path}; bundle exec thin -C config/thin.yml start"
  end

end

namespace :app do
  desc "makes a symbolic link to the shared files"
  task :symlink, :roles => [:web, :app] do
    run "ln -sf #{shared_path}/steam_api_key.rb #{release_path}/config/initializers/steam_api_key.rb"
    run "ln -sf #{shared_path}/database.yml #{release_path}/config/database.yml"
    run "ln -sf #{shared_path}/uploads #{release_path}/public/uploads"
  end

end

namespace :thin do

  desc "Makes a symbolic link to the shared thin.yml"
  task :link_config, :except => { :no_release => true } do
    run "ln -sf #{shared_path}/thin.yml #{release_path}/config/thin.yml"
  end

end

def execute_rake(task_name, path = release_path)
  run "cd #{path} && bundle exec rake RAILS_ENV=#{rails_env} #{task_name}", :env => {'RAILS_ENV' => rails_env}
end

after "deploy:update_code", "thin:link_config"
after "deploy", "deploy:cleanup"
