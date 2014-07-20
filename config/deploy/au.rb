set :main_server,       "au.serveme.tf"
set :user,              'arie'
set :sidekiq_processes,  1
set :puma_flags,        '-w 1 -t 1:16'
set :rvm_ruby_string,   '2.0.0@serveme'
set :rvm_type,          :user

server "#{main_server}", :web, :app, :db, :primary => true
