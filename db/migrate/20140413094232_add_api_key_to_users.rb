class AddApiKeyToUsers < ActiveRecord::Migration
  def change
    add_column :users, :api_key, :string, :limit => 32
    add_index :users, :api_key, :unique => true
    User.all.each do |u|
      u.update_column(:api_key, SecureRandom.hex(16))
    end
  end
end
