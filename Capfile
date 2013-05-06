load 'deploy' if respond_to?(:namespace) # cap2 differentiator
load 'deploy/assets'
load 'config/deploy'
require "bundler/capistrano"
require 'capistrano_colors' unless ENV['COLORIZE_CAPISTRANO'] == 'off'
require 'capistrano/ext/multistage'

require "rvm/capistrano"                  # Load RVM's capistrano plugin.
