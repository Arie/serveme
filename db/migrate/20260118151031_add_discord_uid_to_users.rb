class AddDiscordUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :discord_uid, :string
    add_index :users, :discord_uid, unique: true
  end
end
