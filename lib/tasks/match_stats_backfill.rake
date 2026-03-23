# typed: false
# frozen_string_literal: true

namespace :match_stats do
  desc "Backfill match stats from server_logs/ for ended reservations without match data"
  task backfill: :environment do
    reservation_ids = Reservation
      .where(ended: true)
      .where.not(id: ReservationMatch.select(:reservation_id))
      .order(:id)
      .pluck(:id)

    # Filter to only those with log files on disk
    reservation_ids = reservation_ids.select do |id|
      Dir.glob(Rails.root.join("server_logs", id.to_s, "*.log")).any?
    end

    total = reservation_ids.size
    puts "Found #{total} reservations with logs to process"

    imported = 0
    skipped = 0
    failed = 0
    start_time = Time.current

    reservation_ids.each_with_index do |reservation_id, index|
      log_files = Dir.glob(Rails.root.join("server_logs", reservation_id.to_s, "*.log"))

      any_match = false
      log_files.each do |log_file|
        matches = LogParser.new(log_file).perform
        next if matches.empty?

        ActiveRecord::Base.transaction do
          matches.each_with_index do |match_data, mi|
            reservation_match = ReservationMatch.create!(
              reservation_id: reservation_id,
              red_score: match_data.final_scores["Red"],
              blue_score: match_data.final_scores["Blue"],
              total_duration_seconds: match_data.total_duration_seconds,
              match_number: mi + 1
            )

            red = match_data.final_scores["Red"] || 0
            blue = match_data.final_scores["Blue"] || 0
            winning_team = red == blue ? nil : (red > blue ? "Red" : "Blue")

            match_data.players.each do |player|
              MatchPlayer.create!(
                reservation_match: reservation_match,
                steam_uid: player.steam_uid,
                team: player.team,
                tf2_class: player.tf2_class,
                kills: player.kills,
                deaths: player.deaths,
                assists: player.assists,
                damage: player.damage,
                damage_taken: player.damage_taken,
                healing: player.healing,
                heals_received: player.heals_received,
                ubers: player.ubers,
                drops: player.drops,
                airshots: player.airshots,
                caps: player.caps,
                won: player.team == winning_team
              )
            end
          end
        end
        any_match = true
      rescue StandardError => e
        puts "  FAILED reservation #{reservation_id}: #{e.message}"
        failed += 1
      end

      if any_match
        imported += 1
      else
        skipped += 1
      end

      if (index + 1) % 500 == 0
        elapsed = Time.current - start_time
        rate = (index + 1) / elapsed
        puts "  #{index + 1}/#{total} (#{rate.round(1)}/sec) imported=#{imported} skipped=#{skipped} failed=#{failed}"
      end
    end

    elapsed = Time.current - start_time
    puts "Done in #{elapsed.round(1)}s: imported=#{imported} skipped=#{skipped} failed=#{failed} (of #{total})"
  end
end
