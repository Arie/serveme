# typed: false
# frozen_string_literal: true

namespace :ip_lookup do
  desc "Sync all existing IpLookup records to other regions"
  task sync_all: :environment do
    unless Rails.env.production?
      puts "This task only runs in production. Exiting."
      exit 1
    end

    batch_size = ENV.fetch("BATCH_SIZE", 100).to_i
    delay_seconds = ENV.fetch("DELAY_SECONDS", 0.1).to_f
    total_count = IpLookup.count
    enqueued_count = 0

    puts "Starting IpLookup cross-region sync..."
    puts "Total records to sync: #{total_count}"
    puts "Batch size: #{batch_size}, Delay between batches: #{delay_seconds}s"
    puts "Current region: #{SITE_HOST}"
    puts ""

    IpLookup.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |ip_lookup|
        IpLookupSyncWorker.perform_async(ip_lookup.id)
        enqueued_count += 1
      end

      puts "Enqueued #{enqueued_count}/#{total_count} records..."
      sleep(delay_seconds) if delay_seconds > 0
    end

    puts ""
    puts "Finished enqueueing all IpLookup records for sync."
    puts "Total enqueued: #{enqueued_count}"
    puts "Monitor Sidekiq queue 'low' for progress."
  end

  desc "Sync IpLookup records created after a specific date"
  task sync_since: :environment do
    unless Rails.env.production?
      puts "This task only runs in production. Exiting."
      exit 1
    end

    since_date = ENV.fetch("SINCE", nil)
    unless since_date
      puts "Usage: rake ip_lookup:sync_since SINCE=2024-01-01"
      exit 1
    end

    begin
      since = Time.zone.parse(since_date)
    rescue ArgumentError
      puts "Invalid date format. Use YYYY-MM-DD format."
      exit 1
    end

    batch_size = ENV.fetch("BATCH_SIZE", 100).to_i
    delay_seconds = ENV.fetch("DELAY_SECONDS", 0.1).to_f
    scope = IpLookup.where("created_at >= ?", since)
    total_count = scope.count
    enqueued_count = 0

    puts "Starting IpLookup cross-region sync for records since #{since}..."
    puts "Total records to sync: #{total_count}"
    puts "Batch size: #{batch_size}, Delay between batches: #{delay_seconds}s"
    puts "Current region: #{SITE_HOST}"
    puts ""

    scope.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |ip_lookup|
        IpLookupSyncWorker.perform_async(ip_lookup.id)
        enqueued_count += 1
      end

      puts "Enqueued #{enqueued_count}/#{total_count} records..."
      sleep(delay_seconds) if delay_seconds > 0
    end

    puts ""
    puts "Finished enqueueing IpLookup records for sync."
    puts "Total enqueued: #{enqueued_count}"
    puts "Monitor Sidekiq queue 'low' for progress."
  end

  desc "Show IpLookup sync statistics"
  task stats: :environment do
    total = IpLookup.count
    proxies = IpLookup.where(is_proxy: true).count
    residential_proxies = IpLookup.residential_proxies.count
    recent_24h = IpLookup.where("created_at >= ?", 24.hours.ago).count
    recent_7d = IpLookup.where("created_at >= ?", 7.days.ago).count

    puts "IpLookup Statistics for #{SITE_HOST}"
    puts "=" * 40
    puts "Total records:           #{total}"
    puts "Proxies:                 #{proxies}"
    puts "Residential proxies:     #{residential_proxies}"
    puts "Created in last 24h:     #{recent_24h}"
    puts "Created in last 7 days:  #{recent_7d}"
  end
end
