class AddGrantsPrivateServerToProducts < ActiveRecord::Migration
  def change
    add_column :products, :grants_private_server, :boolean
    add_index :products, :grants_private_server
  end
end
