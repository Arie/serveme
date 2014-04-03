set :main_server,       "na.serveme.tf"
set :user,              'arie'
set :puma_flags,        '-w 2 -t 1:8'
set :sidekiq_processes,  1
set :rvm_ruby_string,   '2.0.0@serveme'

server "#{main_server}", :web, :app, :db, :primary => true

namespace :app do
  desc "symlinks the tragicservers login information"
  task :symlink_tragicservers, :roles => [:web, :app] do
    run "ln -sf #{shared_path}/tragicservers.rb #{release_path}/config/initializers/tragicservers.rb"
  end
end

after "app:symlink", "app:symlink_tragicservers"
