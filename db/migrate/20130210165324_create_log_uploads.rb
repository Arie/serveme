class CreateLogUploads < ActiveRecord::Migration
  def up
    create_table :log_uploads do |t|
      t.integer :reservation_id
      t.string  :file_name
      t.string  :title
      t.string  :map_name
      t.string  :status
      t.string  :url
      t.timestamps
    end
  end

  def down
    drop_table :log_uploads
  end
end
