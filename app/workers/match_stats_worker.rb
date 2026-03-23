# typed: false
# frozen_string_literal: true

class MatchStatsWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: "default"

  def perform(reservation_id)
    reservation = Reservation.find(reservation_id)
    return if ReservationMatch.exists?(reservation_id: reservation_id)

    log_files = Dir.glob(Rails.root.join("server_logs", reservation_id.to_s, "*.log"))
    return if log_files.empty?

    log_files.each do |log_file|
      matches = LogParser.new(log_file).perform
      next if matches.empty?

      ActiveRecord::Base.transaction do
        matches.each_with_index do |match_data, index|
          reservation_match = ReservationMatch.create!(
            reservation_id: reservation_id,
            red_score: match_data.final_scores["Red"],
            blue_score: match_data.final_scores["Blue"],
            total_duration_seconds: match_data.total_duration_seconds,
            match_number: index + 1
          )

          winning_team = determine_winning_team(match_data)

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
    end

    LiveMatchStats.clear(reservation_id)
  end

  private

  def determine_winning_team(match_data)
    red = match_data.final_scores["Red"] || 0
    blue = match_data.final_scores["Blue"] || 0
    return nil if red == blue

    red > blue ? "Red" : "Blue"
  end
end
