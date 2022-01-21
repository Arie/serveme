class AddIndexToTypeOnServers < ActiveRecord::Migration[7.0]
  def change
    add_index :servers, :type
  end
end
