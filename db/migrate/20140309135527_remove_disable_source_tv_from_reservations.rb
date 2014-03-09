class RemoveDisableSourceTvFromReservations < ActiveRecord::Migration
  def change
    remove_column :reservations, :disable_source_tv
  end
end
