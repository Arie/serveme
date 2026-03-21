# frozen_string_literal: true

class AddDemocheckModeToReservations < ActiveRecord::Migration[7.2]
  def up
    add_column :reservations, :democheck_mode, :string, default: "kick", null: false
    execute "UPDATE reservations SET democheck_mode = 'disable' WHERE disable_democheck = true"
    remove_column :reservations, :disable_democheck
  end

  def down
    add_column :reservations, :disable_democheck, :boolean, default: false
    execute "UPDATE reservations SET disable_democheck = true WHERE democheck_mode = 'disable'"
    remove_column :reservations, :democheck_mode
  end
end
