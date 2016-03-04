set :main_server,       "wilhelm.fakkelbrigade.eu"
set :user,              'arie'
set :puma_flags,        '-w 2 -t 1:4'
set :sidekiq_processes,  2

server "#{main_server}", :web, :app, :db, :primary => true

namespace :app do
  desc "symlinks the NFO servers login information"
  task :symlink_nfoservers, :roles => [:web, :app] do
    run "rm #{release_path}/config/initializers/tragicservers.rb"
    run "ln -sf #{shared_path}/config/initializers/nfoservers.rb #{release_path}/config/initializers/nfoservers.rb"
  end
end
after "app:symlink", "app:symlink_nfoservers"
