class AddEnablePluginsToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :enable_plugins, :boolean, :default => false
  end
end
