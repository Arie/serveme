class IncreaseWhitelistTfSize < ActiveRecord::Migration
  def change
    change_column :whitelist_tfs, :content, :text, :limit => 10.megabyte
  end
end
