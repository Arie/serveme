class ChangeEndInstantlyToDefaultToFalse < ActiveRecord::Migration
  def change
    change_column :reservations, :end_instantly, :boolean, :default => false
  end
end
