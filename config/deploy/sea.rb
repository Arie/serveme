set :main_server,       "139.99.42.241"
set :user,              'arie'
set :puma_threads,      [0,4]
set :puma_workers,       1
set :sidekiq_processes,  1
set :rvm_type,           :user

server "139.99.42.241", user: "arie", roles: ["web", "app", "db"]
