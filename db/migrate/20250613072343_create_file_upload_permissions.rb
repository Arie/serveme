class CreateFileUploadPermissions < ActiveRecord::Migration[7.0]
  def change
    create_table :file_upload_permissions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :allowed_paths, array: true, default: []

      t.timestamps
    end
  end
end
