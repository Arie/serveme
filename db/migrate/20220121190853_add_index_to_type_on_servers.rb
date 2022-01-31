class AddIndexToTypeOnServers < ActiveRecord::Migration[6.1]
  def change
    add_index :servers, :type
  end
end
