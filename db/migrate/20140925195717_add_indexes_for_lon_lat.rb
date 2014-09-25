class AddIndexesForLonLat < ActiveRecord::Migration
  def change
    add_index :servers, [:latitude, :longitude]
    add_index :users, [:latitude, :longitude]
  end
end
