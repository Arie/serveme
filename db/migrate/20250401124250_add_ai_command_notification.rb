# typed: true

class AddAiCommandNotification < ActiveRecord::Migration[8.0]
  def up
    ServerNotification.create!(
      message: "New: Use !ai in chat to control the server! Ask for map changes, configs, or anything else. The AI will help you manage the server",
      notification_type: "public"
    )
  end

  def down
    ServerNotification.where(
      message: "New: Use !ai in chat to control the server! Ask for map changes, configs, or anything else. The AI will help you manage the server",
    ).delete_all
  end
end
