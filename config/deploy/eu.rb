# typed: false
# frozen_string_literal: true

set :main_server,       'new.fakkelbrigade.eu'
set :puma_threads,      [0, 8]
set :puma_workers,       2
set :sidekiq_processes,  2
set :rvm_type, :user
server 'new.fakkelbrigade.eu', user: 'tf2', roles: %w[web app db]
