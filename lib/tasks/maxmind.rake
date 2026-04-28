# typed: false
# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# Guard against double-load: the geocoder gem's railtie re-loads lib/tasks/*.rake,
# which would otherwise cause the task body to run twice when invoked.
unless Rake::Task.task_defined?("maxmind:fetch")
  namespace :maxmind do
    desc "Download fresh GeoLite2 databases from MaxMind into doc/"
    task fetch: :environment do
      license_key = Rails.application.credentials.dig(:maxmind, :license_key)
      raise "Missing maxmind.license_key in Rails credentials. Add it via: rails credentials:edit" if license_key.blank?

      Dir.mktmpdir("maxmind-fetch") do |tmp|
        %w[GeoLite2-ASN GeoLite2-City].each do |edition|
          puts "Fetching #{edition}..."
          tarball = File.join(tmp, "#{edition}.tar.gz")
          url = "https://download.maxmind.com/app/geoip_download?edition_id=#{edition}&license_key=#{license_key}&suffix=tar.gz"

          # Avoid echoing the URL (which contains the license key) to stdout.
          system("curl", "-fsSL", "-o", tarball, url, exception: true)
          system("tar", "-xzf", tarball, "-C", tmp, exception: true)

          extracted = Dir.glob(File.join(tmp, "#{edition}_*", "#{edition}.mmdb")).first
          raise "Could not find #{edition}.mmdb in extracted tarball" unless extracted

          target = Rails.root.join("doc", "#{edition}.mmdb")
          tmp_target = "#{target}.tmp"
          FileUtils.mv(extracted, tmp_target)
          File.rename(tmp_target, target)
          puts "  -> #{target} (#{File.size(target)} bytes, mtime #{File.mtime(target)})"
        end
      end

      puts "Done."
    end
  end
end
