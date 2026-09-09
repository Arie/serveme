# typed: true
# frozen_string_literal: true

class AddSharedIpToIpLookups < ActiveRecord::Migration[8.1]
  def change
    add_column :ip_lookups, :shared_ip, :boolean, null: false, default: false
  end
end
