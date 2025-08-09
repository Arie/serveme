# typed: false

namespace :maxmind do
  desc "Update MaxMind GeoLite2 databases"
  task :update do
    on roles(:app) do
      info "Starting MaxMind database update..."

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

      info "MaxMind database update completed!"
    end
  end
end
