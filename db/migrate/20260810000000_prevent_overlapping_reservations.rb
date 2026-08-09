# typed: false
# frozen_string_literal: true

class PreventOverlappingReservations < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"

    # Cancelling a future reservation sets ends_at to the moment of cancelling,
    # so it can end before it starts. tsrange() raises on an inverted range, and
    # Postgres evaluates the expression for rows the WHERE clause excludes too,
    # so clamp it: those reservations get an empty range and collide with nothing.
    add_exclusion_constraint :reservations,
                             "server_id WITH =, tsrange(starts_at, GREATEST(starts_at, ends_at)) WITH &&",
                             using: :gist,
                             where: "ended = false",
                             name: "no_overlapping_reservations"
  end
end
