# typed: true
# frozen_string_literal: true

class ScoreboardStats
  extend T::Sig

  sig { params(reservation_match: ReservationMatch).returns(T::Hash[Symbol, T.untyped]) }
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
      },
      total_duration_seconds: reservation_match.total_duration_seconds
    }
  end
end
