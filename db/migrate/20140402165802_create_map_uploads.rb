class CreateMapUploads < ActiveRecord::Migration
  def change
    create_table :map_uploads do |t|
      t.string :name
      t.string :file
      t.integer :user_id, :null => false
      t.timestamps
    end
  end
end
