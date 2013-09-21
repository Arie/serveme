class AddMissingIndexes < ActiveRecord::Migration
  def change
    add_index :log_uploads, :reservation_id
    add_index :reservations, :user_id
    add_index :reservations, :starts_at
    add_index :users, :uid
    add_index :whitelist_tfs, :tf_whitelist_id
  end
end
