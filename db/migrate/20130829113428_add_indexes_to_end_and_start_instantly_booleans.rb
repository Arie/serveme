class AddIndexesToEndAndStartInstantlyBooleans < ActiveRecord::Migration
  def change
    add_index :reservations, :start_instantly
    add_index :reservations, :end_instantly
  end
end
