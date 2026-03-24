# frozen_string_literal: true

class DeduplicateReservationMatches < ActiveRecord::Migration[7.2]
  def up
    # Delete duplicate reservation_matches, keeping the one with the lowest id per (reservation_id, match_number)
    execute <<~SQL
      DELETE FROM match_players
      WHERE reservation_match_id IN (
        SELECT rm.id FROM reservation_matches rm
        WHERE rm.id NOT IN (
          SELECT MIN(id) FROM reservation_matches
          GROUP BY reservation_id, match_number
        )
      )
    SQL

    execute <<~SQL
      DELETE FROM reservation_matches
      WHERE id NOT IN (
        SELECT MIN(id) FROM reservation_matches
        GROUP BY reservation_id, match_number
      )
    SQL

    add_index :reservation_matches, [ :reservation_id, :match_number ], unique: true, if_not_exists: true
  end

  def down
    remove_index :reservation_matches, [ :reservation_id, :match_number ]
  end
end
