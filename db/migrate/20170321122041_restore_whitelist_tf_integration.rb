class RestoreWhitelistTfIntegration < ActiveRecord::Migration[5.0]
  def change
    create_table :whitelist_tfs do |t|
      t.integer :tf_whitelist_id
      t.text :content
      t.timestamps
    end

    add_index :whitelist_tfs, :tf_whitelist_id
  end
end
