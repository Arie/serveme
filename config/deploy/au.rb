set :main_server,       "direct.au.serveme.tf"
set :user,              'arie'
set :puma_flags,        '-w 2 -t 1:4'
set :sidekiq_processes,  1
set :rvm_type,          :user

server "#{main_server}", :web, :app, :db, :primary => true

namespace :logdaemon do
  desc "Start the logdaemon process"
  task :start, :roles => lambda { roles } do
    run "cd #{current_path};#{rails_env} #{logdaemon_command} -i 172.31.9.240 -p 40001 -d -l #{logdaemon_log} -P #{logdaemon_pid}"
  end
end
