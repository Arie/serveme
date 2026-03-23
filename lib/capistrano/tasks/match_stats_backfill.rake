# typed: false

namespace :match_stats do
  desc "Backfill match stats from server_logs"
  task :backfill do
    on roles(:app), in: :sequence do
      within release_path do
        with rails_env: fetch(:rails_env) do
          info "Starting match stats backfill..."
          rake "match_stats:backfill"
          info "Match stats backfill completed!"
        end
      end
    end
  end

  desc "Deploy and run match stats backfill"
  task :deploy_and_backfill do
    invoke "deploy"
    invoke "match_stats:backfill"
  end
end
