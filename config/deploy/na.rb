# frozen_string_literal: true

set :main_server,       'direct.na.serveme.tf'
set :user,              'arie'
set :puma_threads,      [0, 15]
set :puma_workers,       2
set :sidekiq_processes,  2
set :rvm_type,           :user

server 'direct.na.serveme.tf', user: 'arie', roles: %w[web app db]
