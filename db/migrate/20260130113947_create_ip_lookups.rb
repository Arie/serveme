# frozen_string_literal: true

class CreateIpLookups < ActiveRecord::Migration[8.1]
  def change
    create_table :ip_lookups do |t|
      t.string :ip, null: false
      t.boolean :is_proxy, default: false
      t.boolean :is_residential_proxy, default: false
      t.integer :fraud_score
      t.string :connection_type
      t.string :isp
      t.string :country_code
      t.jsonb :raw_response

      t.timestamps
    end

    add_index :ip_lookups, :ip, unique: true
    add_index :ip_lookups, :is_residential_proxy
  end
end
