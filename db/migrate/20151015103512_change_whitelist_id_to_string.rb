class ChangeWhitelistIdToString < ActiveRecord::Migration
  def change
    change_column :reservations, :custom_whitelist_id, :string
  end
end
