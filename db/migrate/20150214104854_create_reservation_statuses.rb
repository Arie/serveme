class CreateReservationStatuses < ActiveRecord::Migration
  def change
    create_table :reservation_statuses do |t|
      t.integer :reservation_id
      t.string :status, :limit => 191
      t.timestamps
    end
    add_index :reservation_statuses, :reservation_id
    add_index :reservation_statuses, :created_at
  end
end
