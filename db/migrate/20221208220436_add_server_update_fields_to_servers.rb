# typed: true
class AddServerUpdateFieldsToServers < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :last_known_version, :integer
    add_column :servers, :update_started_at, :datetime
    add_column :servers, :update_status, :string
  end
end
