# typed: false
# frozen_string_literal: true

class ScoreboardStats
  def self.from_match(reservation_match)
    players = reservation_match.match_players.map do |mp|
      {
        steam_uid: mp.steam_uid,
        name: mp.user&.nickname || mp.steam_uid.to_s,
        team: mp.team,
        tf2_class: mp.tf2_class,
        kills: mp.kills,
        assists: mp.assists,
        deaths: mp.deaths,
        damage: mp.damage,
        damage_taken: mp.damage_taken,
        healing: mp.healing,
        heals_received: mp.heals_received,
        ubers: mp.ubers,
        drops: mp.drops,
        airshots: mp.airshots,
        caps: mp.caps
      }
    end

    {
      players: players,
      scores: {
        "Red" => reservation_match.red_score || 0,
        "Blue" => reservation_match.blue_score || 0
      }
    }
  end
end
