class AddEnableDemosTfToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :enable_demos_tf, :boolean, default: false
  end
end
