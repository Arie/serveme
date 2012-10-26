class AddTimestampsToTables < ActiveRecord::Migration
  def change
    change_table :users do |t|
      t.timestamps
    end
    change_table :servers do |t|
      t.timestamps
    end

    change_table :reservations do |t|
      t.timestamps
    end
  end
end
