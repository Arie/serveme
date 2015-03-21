class AddBillingIdToServers < ActiveRecord::Migration
  def change
    add_column :servers, :billing_id, :string
  end
end
