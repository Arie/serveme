class CreateLocations < ActiveRecord::Migration
  def up
    create_table :locations do |t|
      t.string :name
      t.string :flag
      t.timestamps
    end
    add_column :servers, :location_id, :integer
  end

  def down
    remove_column :servers, :location_id
    drop_table :locations
  end
end
