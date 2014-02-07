set :main_server,       "na.fakkelbrigade.eu"
set :user,              'arie'
set :puma_flags,        '-w 2 -t 1:8'
set :sidekiq_processes,  1

server "#{main_server}", :web, :app, :db, :primary => true
