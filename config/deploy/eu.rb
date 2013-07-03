set :main_server,       "fakkelbrigade.eu"
set :user,              'tf2'
set :puma_socket,       'tcp://127.0.0.1:3010'

server "#{main_server}", :web, :app, :db, :primary => true
