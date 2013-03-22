class AddActiveBooleanToServers < ActiveRecord::Migration
  def change
    add_column :servers, :active, :boolean, :default => true
  end
end
