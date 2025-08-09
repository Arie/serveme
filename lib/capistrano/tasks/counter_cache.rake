# typed: false
# frozen_string_literal: true

namespace :counter_cache do
  desc "Backfill counter cache data for users and servers"
  task :backfill do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "counter_cache:backfill"
        end
      end
    end
  end

  desc "Reset counter caches to zero"
  task :reset do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:console", "DISABLE_DATABASE_ENVIRONMENT_CHECK=1", input: <<~SQL
            User.update_all(reservations_count: 0, total_reservation_seconds: 0);
            Server.update_all(reservations_count: 0);
          SQL
        end
      end
    end
  end
end

# Hook to run after migrations if desired
# after 'deploy:migrate', 'counter_cache:backfill'
