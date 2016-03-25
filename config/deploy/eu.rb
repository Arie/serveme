set :main_server,       "fakkelbrigade.eu"
set :puma_bind,         'tcp://127.0.0.1:3010'
set :puma_threads,      [0,8]
set :puma_workers,      2
set :sidekiq_processes, 2
server "fakkelbrigade.eu", user: "tf2", roles: ["web", "app", "db"]

namespace :app do
  desc "symlinks the NFO servers login information"
  task :symlink_nfoservers do
    on roles(:web, :app) do
      execute "rm #{release_path}/config/initializers/tragicservers.rb"
      execute "ln -sf #{shared_path}/config/initializers/nfoservers.rb #{release_path}/config/initializers/nfoservers.rb"
    end
  end
end
after "deploy:symlink:linked_files", "app:symlink_nfoservers"

namespace :app do
  desc "symlinks the simrai api information"
  task :symlink_simrai do
    on roles(:web, :app) do
      execute "ln -sf #{shared_path}/config/initializers/simrai.rb #{release_path}/config/initializers/simrai.rb"
    end
  end
end
after "deploy:symlink:linked_files", "app:symlink_simrai"
