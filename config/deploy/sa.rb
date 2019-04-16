set :main_server,       "direct.sa.serveme.tf"
set :user,              'arie'
set :puma_threads,      [0,4]
set :puma_workers,      2
set :sidekiq_processes,  1
set :rvm_type,           :user

server "direct.sa.serveme.tf", user: "arie", roles: ["web", "app", "db"]
