class AddDiscordFieldsToReservations < ActiveRecord::Migration[8.1]
  def change
    add_column :reservations, :discord_channel_id, :string
    add_column :reservations, :discord_message_id, :string
  end
end
