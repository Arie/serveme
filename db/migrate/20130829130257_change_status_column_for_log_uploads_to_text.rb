class ChangeStatusColumnForLogUploadsToText < ActiveRecord::Migration
  def change
    change_column :log_uploads, :status, :text
  end
end
