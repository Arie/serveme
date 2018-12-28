set :main_server,       "139.99.121.10"
set :user,              'serveme'
set :puma_threads,      [0,4]
set :puma_workers,       1
set :sidekiq_processes,  1
set :rvm_type,           :user
set :logdaemon_host,     "10.20.0.5"

server "139.99.121.10", user: "serveme", roles: ["web", "app", "db"], port: 50000
