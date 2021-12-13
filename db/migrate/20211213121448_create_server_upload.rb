class CreateServerUpload < ActiveRecord::Migration[6.1]
  def change
    create_table :server_uploads do |t|
      t.integer :server_id
      t.integer :file_upload_id
      t.datetime :started_at
      t.datetime :uploaded_at

      t.timestamps
    end

    add_index :server_uploads, :server_id
    add_index :server_uploads, :file_upload_id
    add_index :server_uploads, :uploaded_at
    add_index :server_uploads, [:server_id, :file_upload_id], unique: true
  end
end
