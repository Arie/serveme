class AddStatisticsIndexesAndCounterCaches < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for statistics performance
    add_index :reservations, [ :starts_at, :duration ], name: 'index_reservations_on_starts_at_and_duration'
    add_index :reservations, :created_at, name: 'index_reservations_on_created_at'

    # Add counter cache columns to users
    add_column :users, :reservations_count, :integer, default: 0, null: false
    add_column :users, :total_reservation_seconds, :bigint, default: 0, null: false

    # Add counter cache column to servers
    add_column :servers, :reservations_count, :integer, default: 0, null: false

    # Add indexes on the new counter columns for faster queries
    add_index :users, :reservations_count
    add_index :users, :total_reservation_seconds
    add_index :servers, :reservations_count
  end
end
