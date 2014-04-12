class AddTypeToServerNotifications < ActiveRecord::Migration
  def change
    add_column :server_notifications, :notification_type, :string, :limit => 191
    ServerNotification.all.each do |sn|
      if sn.ad?
        sn.notification_type = "ad"
      else
        sn.notification_type = "public"
      end
      sn.save
    end

    remove_column :server_notifications, :ad
  end
end
