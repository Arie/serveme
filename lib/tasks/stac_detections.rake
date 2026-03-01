# typed: false
# frozen_string_literal: true

namespace :stac do
  desc "Backfill stac_detections from existing stac_logs"
  task backfill_detections: :environment do
    total = StacLog.count
    processed = 0
    created = 0

    StacLog.find_each do |stac_log|
      processed += 1

      next unless stac_log.contents.present?

      begin
        processor = StacLogProcessor.new(stac_log.reservation)
        all_detections = processor.extract_detections(stac_log.contents)

        all_detections.each_value do |data|
          detection_counts = data[:detections].tally
          detection_counts.each do |detection_type, count|
            StacDetection.find_or_create_by!(
              reservation_id: stac_log.reservation_id,
              steam_uid: data[:steam_id64],
              detection_type: detection_type,
              stac_log_id: stac_log.id
            ) do |d|
              d.player_name = data[:name]
              d.steam_id = data[:steam_id]
              d.count = count
            end
            created += 1
          end
        end
      rescue StandardError => e
        puts "Error processing stac_log #{stac_log.id}: #{e.message}"
      end

      print "\rProcessed #{processed}/#{total} stac_logs, created #{created} detections" if (processed % 100).zero? || processed == total
    end

    puts "\nDone. Processed #{processed} stac_logs, created #{created} detections."
  end
end
