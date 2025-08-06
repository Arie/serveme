# typed: false
# frozen_string_literal: true

set :main_server,       "direct.au.serveme.tf"
set :user,              "tf2"
set :puma_threads,      [ 0, 8 ]
set :puma_workers,       1
set :sidekiq_processes,  1
set :rvm_type,           :user

set :puma_phased_restart, false

server "direct.au.serveme.tf", user: "tf2", roles: %w[web app db]
