set :main_server,       "direct.au.serveme.tf"
set :user,              'arie'
set :puma_flags,        '-w 2 -t 1:4'
set :sidekiq_processes,  1
set :rvm_type,          :user

server "#{main_server}", :web, :app, :db, :primary => true
