set :main_server,       "fakkelbrigade.eu"
set :user,              'tf2'
set :puma_socket,       'tcp://127.0.0.1:3010'
set :puma_flags,        '-w 2 -t 1:4'
set :sidekiq_processes,  2

server "#{main_server}", :web, :app, :db, :primary => true

namespace :app do
  desc "symlinks the NFO servers login information"
  task :symlink_nfoservers, :roles => [:web, :app] do
    run "rm #{release_path}/config/initializers/tragicservers.rb"
    run "ln -sf #{shared_path}/nfoservers.rb #{release_path}/config/initializers/nfoservers.rb"
  end
end

after "app:symlink", "app:symlink_nfoservers"

namespace :app do
  desc "symlinks the hiperz api information"
  task :symlink_hiperz, :roles => [:web, :app] do
    run "ln -sf #{shared_path}/hiperz.rb #{release_path}/config/initializers/hiperz.rb"
  end
end

after "app:symlink", "app:symlink_hiperz"

namespace :app do
  desc "symlinks the simrai api information"
  task :symlink_simrai, :roles => [:web, :app] do
    run "ln -sf #{shared_path}/simrai.rb #{release_path}/config/initializers/simrai.rb"
  end
end

after "app:symlink", "app:symlink_simrai"
