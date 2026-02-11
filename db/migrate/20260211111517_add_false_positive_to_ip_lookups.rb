# frozen_string_literal: true

class AddFalsePositiveToIpLookups < ActiveRecord::Migration[8.1]
  def change
    add_column :ip_lookups, :false_positive, :boolean, default: false
  end
end
