# typed: false

namespace :asn do
  desc "Backfill ASN data for reservation players"
  task :backfill do
    on roles(:app), in: :sequence do
      within release_path do
        with rails_env: fetch(:rails_env) do
          info "Starting ASN data backfill..."
          info "This will update ASN information for all reservation players with IP addresses"

          rake "reservation_players:backfill_asn_data_bulk"

          info "ASN backfill completed!"
        end
      end
    end
  end

  desc "Check ASN backfill progress"
  task :status do
    on roles(:app), in: :sequence do
      within release_path do
        with rails_env: fetch(:rails_env) do
          info "Checking ASN backfill status..."

          # Use rake command which handles bundler properly
          rake "reservation_players:asn_status"
        end
      end
    end
  end

  desc "Deploy and run ASN backfill"
  task :deploy_and_backfill do
    invoke "deploy"
    invoke "asn:backfill"
  end
end
