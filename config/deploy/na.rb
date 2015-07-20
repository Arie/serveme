set :main_server,       "direct.na.serveme.tf"
set :user,              'arie'
set :sidekiq_processes,  1
set :puma_flags,        '-w 2 -t 1:4'

server "#{main_server}", :web, :app, :db, :primary => true

namespace :app do
  desc "symlinks the tragicservers login information"
  task :symlink_tragicservers, :roles => [:web, :app] do
    run "ln -sf #{shared_path}/tragicservers.rb #{release_path}/config/initializers/tragicservers.rb"
  end
end

after "app:symlink", "app:symlink_tragicservers"
