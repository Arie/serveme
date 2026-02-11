class AddBanFieldsToIpLookups < ActiveRecord::Migration[8.1]
  def change
    add_column :ip_lookups, :is_banned, :boolean, default: false
    add_column :ip_lookups, :ban_reason, :string
  end
end
