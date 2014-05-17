class RemoveWhitelistTf < ActiveRecord::Migration

  def change
    drop_table :whitelist_tfs
  end

end
