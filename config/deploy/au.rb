set :main_server,       "direct.au.serveme.tf"
set :user,              'arie'
set :sidekiq_processes,  1
set :puma_flags,        '-w 1 -t 1:16'
set :rvm_type,          :user
set :rvm_ruby_string,   '2.0.0@serveme'

server "#{main_server}", :web, :app, :db, :primary => true
