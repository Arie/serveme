class CreateRatings < ActiveRecord::Migration
  def change
    create_table :ratings do |t|
      t.integer :reservation_id
      t.string :steam_uid,  :limit => 191
      t.string :nickname,   :limit => 191
      t.string :opinion,    :limit => 191
      t.string :reason,     :limit => 191
      t.timestamps
    end

    add_index :ratings, :reservation_id
    add_index :ratings, :steam_uid
    add_index :ratings, :opinion
  end
end
