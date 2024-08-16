# typed: true
class AddHiddenToWhitelists < ActiveRecord::Migration[7.1]
  def change
    add_column :whitelists, :hidden, :boolean, default: false
    add_index :whitelists, :hidden
  end
end
