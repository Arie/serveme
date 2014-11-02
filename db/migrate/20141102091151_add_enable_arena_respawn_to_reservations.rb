class AddEnableArenaRespawnToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :enable_arena_respawn, :boolean, :default => false
  end
end
