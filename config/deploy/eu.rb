set :deploy_to,         "/var/www/serveme"
set :main_server,       "fakkelbrigade.eu"
set :user,              'tf2'

server "#{main_server}", :web, :app, :db, :primary => true
