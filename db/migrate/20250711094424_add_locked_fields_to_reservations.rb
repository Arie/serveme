# typed: true

class AddLockedFieldsToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :original_password, :text
    add_column :reservations, :locked_at, :datetime
  end
end
