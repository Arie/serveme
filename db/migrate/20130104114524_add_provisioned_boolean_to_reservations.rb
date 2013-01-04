class AddProvisionedBooleanToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :provisioned, :boolean, :default => false
  end
end
