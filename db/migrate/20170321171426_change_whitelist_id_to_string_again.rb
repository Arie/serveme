class ChangeWhitelistIdToStringAgain < ActiveRecord::Migration[5.0]
  def change
    change_column :whitelist_tfs, :tf_whitelist_id, :string
  end
end
