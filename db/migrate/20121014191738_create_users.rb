class CreateUsers < ActiveRecord::Migration
  def up
    create_table :users do |t|
      t.string :uid,      :limit => 191
      t.string :provider, :limit => 191
      t.string :name,     :limit => 191
      t.string :nickname, :limit => 191
    end
  end

  def down
    drop_table :users
  end
end
