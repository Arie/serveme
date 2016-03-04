class AddMissingIndexes < ActiveRecord::Migration
  def change
    add_index :reservations, :user_id
    add_index :users, :uid
  end
end
