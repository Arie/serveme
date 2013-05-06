require 'puma/capistrano'

set :deploy_to,         "/var/www/serveme"
set :main_server,       "na.fakkelbrigade.eu"
set :user,              'arie'

server "#{main_server}", :web, :app, :db, :primary => true

before 'deploy:restart',  'deploy:web:disable'
after 'deploy:restart',   'deploy:web:enable'
