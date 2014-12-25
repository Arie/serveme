set :main_server,       "fakkelbrigade.eu"
set :user,              'tf2'
set :puma_socket,       'tcp://127.0.0.1:3010'
set :puma_flags,        '-w 4 -t 1:8'
set :sidekiq_processes,  2
set :sidekiq_concurrency, 10

server "#{main_server}", :web, :app, :db, :primary => true

namespace :app do
  desc "symlinks the NFO servers login information"
  task :symlink_nfoservers, :roles => [:web, :app] do
    run "rm #{release_path}/config/initializers/tragicservers.rb"
    run "ln -sf #{shared_path}/nfoservers.rb #{release_path}/config/initializers/nfoservers.rb"
  end
end

after "app:symlink", "app:symlink_nfoservers"
