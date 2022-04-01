class AddIpIndexToServers < ActiveRecord::Migration[6.1]
  def change
    add_index :servers, :ip
  end
end
