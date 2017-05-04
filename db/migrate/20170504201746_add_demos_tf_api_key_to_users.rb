class AddDemosTfApiKeyToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :demos_tf_api_key, :string
  end
end
