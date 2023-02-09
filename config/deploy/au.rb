set :main_server,       "rsl.tf"
set :user,              'arie'
set :puma_threads,      [0,8]
set :puma_workers,       1
set :sidekiq_processes,  1
set :rvm_type,           :user
set :pty,                false

server "rsl.tf", user: "arie", roles: ["web", "app", "db"]
