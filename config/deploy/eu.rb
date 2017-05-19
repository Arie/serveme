set :main_server,       "wilhelm.fakkelbrigade.eu"
set :puma_bind,         'tcp://127.0.0.1:3010'
set :puma_bind,         'unix:///var/www/serveme/shared/sockets/puma.sock'
set :puma_threads,      [1,4]
set :puma_workers,      2
set :sidekiq_processes, 2
server "wilhelm.fakkelbrigade.eu", user: "arie", roles: ["web", "app", "db"]
