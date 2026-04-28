# typed: false

namespace :maxmind do
  desc "Upload GeoLite2 databases from doc/ to the stage and restart"
  task :upload do
    on roles(:app) do
      info "Starting MaxMind database upload..."

      invoke "maintenance:enable"

      invoke "puma:stop"
      invoke "sidekiq:stop"

      info "Uploading GeoLite2-City.mmdb..."
      upload! "doc/GeoLite2-City.mmdb", "#{shared_path}/doc/GeoLite2-City.mmdb"

      info "Uploading GeoLite2-ASN.mmdb..."
      upload! "doc/GeoLite2-ASN.mmdb", "#{shared_path}/doc/GeoLite2-ASN.mmdb"

      invoke "sidekiq:start"
      invoke "puma:restart"

      invoke "maintenance:disable"

      info "MaxMind database upload completed!"
    end
  end
end
