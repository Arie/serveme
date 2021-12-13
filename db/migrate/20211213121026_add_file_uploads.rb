class AddFileUploads < ActiveRecord::Migration[6.1]
  def change
    create_table :file_uploads do |t|
      t.string :file
      t.integer :user_id
      t.timestamps
    end
  end
end
