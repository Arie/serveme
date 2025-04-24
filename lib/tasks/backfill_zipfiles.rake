# typed: false

# desc "Enqueues Sidekiq jobs to upload existing local zip files to Active Storage (Minio)."
namespace :backfill do
  task enqueue_zipfiles: :environment do
    uploads_dir = Rails.root.join("public", "uploads")
    # Match only the specific numeric/hyphenated format
    zip_pattern = uploads_dir.join("[0-9]*-[0-9]*-[0-9]*-[0-9]*.zip")
    processed_count = 0
    enqueued_count = 0

    puts "Starting zip file backfill enqueue process..."
    puts "Scanning #{uploads_dir} for files matching #{zip_pattern}..."

    Dir.glob(zip_pattern).each do |file_path|
      processed_count += 1
      filename = File.basename(file_path)

      # Extract reservation ID (second number) from filename, e.g., "STEAMID-RESERVATIONID-SERVERID-DATE.zip"
      match = filename.match(/^\d+-(\d+)-\d+-\d+\.zip$/)
      unless match
        puts "Skipping file with unexpected name format: #{filename}"
        next
      end

      reservation_id = match[1].to_i
      if reservation_id.zero?
        puts "Skipping file with invalid reservation ID 0: #{filename}"
        next
      end

      # Execute the worker's logic synchronously instead of enqueuing.
      begin
        BackfillZipfileWorker.new.perform(reservation_id)
        enqueued_count += 1 # Technically "processed" count now
      rescue StandardError => e
        # Log errors but continue with the next file
        puts "ERROR processing #{filename} for reservation #{reservation_id}: #{e.message}"
      end

      # Log progress periodically
      if processed_count % 10 == 0
        puts "Processed #{processed_count} files, attempted upload for #{enqueued_count} files..."
      end
    end

    puts "Finished synchronous backfill process."
    puts "Total files scanned:        #{processed_count}"
    puts "Files processed by worker: #{enqueued_count}"
  end
end
