class CreateServerNotifications < ActiveRecord::Migration
  def change
    create_table :server_notifications do |t|
      t.string :message, :limit => 190
      t.boolean :ad
    end
  end
end
