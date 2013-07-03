class AddIndexes < ActiveRecord::Migration
  def change
    add_index :servers,       :location_id
    add_index :servers,       :active

    add_index :reservations,  :starts_at
    add_index :reservations,  :ends_at
    add_index :reservations,  :server_id

    add_index :groups,        :name

    add_index :group_users,   :group_id
    add_index :group_users,   :user_id

    add_index :group_servers,   :group_id
    add_index :group_servers,   :server_id
  end
end
