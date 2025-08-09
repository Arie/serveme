# typed: false
# frozen_string_literal: true

namespace :counter_cache do
  desc "Backfill counter cache data for users and servers"
  task backfill: :environment do
    puts "Backfilling counter caches..."

    # Backfill user reservations_count and total_reservation_seconds
    puts "Updating User counter caches..."
    User.find_in_batches(batch_size: 100) do |users|
      users.each do |user|
        reservations_count = user.reservations.count
        total_seconds = user.reservations.sum(:duration) || 0

        user.update_columns(
          reservations_count: reservations_count,
          total_reservation_seconds: total_seconds
        )

        print "."
      end
    end

    puts "\nUpdating Server counter caches..."
    Server.find_in_batches(batch_size: 100) do |servers|
      servers.each do |server|
        reservations_count = server.reservations.count
        server.update_column(:reservations_count, reservations_count)
        print "."
      end
    end

    puts "\nCounter cache backfill complete!"
  end
end
