set :deploy_to,         "/var/www/serveme"
set :main_server,       "fakkelbrigade.eu"
set :user,              'tf2'

server "#{main_server}", :web, :app, :db, :primary => true

after "deploy:update_code", "thin:link_config"
before 'deploy:restart',    'deploy:web:disable'
after 'deploy:restart',     'deploy:web:enable'

namespace :thin do

  desc "Makes a symbolic link to the shared thin.yml"
  task :link_config, :except => { :no_release => true } do
    run "ln -sf #{shared_path}/thin.yml #{release_path}/config/thin.yml"
  end

end

namespace :deploy do
  desc "Restart the servers"
  task :restart do
    run "cd #{release_path}; bundle exec thin -C config/thin.yml stop"
    run "cd #{release_path}; bundle exec thin -C config/thin.yml start"
  end
end

