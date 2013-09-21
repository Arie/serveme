class AddMissingIndexes < ActiveRecord::Migration
  def change
    add_index :log_uploads, :reservation_id
    add_index :reservations, :user_id
    add_index :users, :uid
  end
end
