class CreateVersions < ActiveRecord::Migration
  def self.up
    create_table :versions do |t|
      t.string   :item_type, :null => false, :limit => 191
      t.integer  :item_id,   :null => false
      t.string   :event,     :null => false, :limit => 191
      t.string   :whodunnit, :limit => 191
      t.text     :object
      t.datetime :created_at
    end
    add_index :versions, [:item_type, :item_id]
  end

  def self.down
    remove_index :versions, [:item_type, :item_id]
    drop_table :versions
  end
end
