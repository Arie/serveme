class AddDisableSourceTvToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :disable_source_tv, :boolean, :default => false
  end
end
