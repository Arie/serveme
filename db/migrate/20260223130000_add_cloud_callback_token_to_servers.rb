class AddCloudCallbackTokenToServers < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :cloud_callback_token, :string
  end
end
