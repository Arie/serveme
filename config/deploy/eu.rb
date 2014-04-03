set :main_server,       "fakkelbrigade.eu"
set :user,              'tf2'
set :puma_socket,       'tcp://127.0.0.1:3010'
set :puma_flags,        '-w 4 -t 1:8'
set :sidekiq_processes,  2
set :branch,            "map_upload"

server "#{main_server}", :web, :app, :db, :primary => true
