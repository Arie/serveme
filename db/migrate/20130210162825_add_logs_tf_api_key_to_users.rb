class AddLogsTfApiKeyToUsers < ActiveRecord::Migration
  def change
    add_column :users, :logs_tf_api_key, :string
  end
end
