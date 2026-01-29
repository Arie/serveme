class AddIndexToReservationsForActivePast < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :reservations, [ :ended, :provisioned, :ends_at ],
              algorithm: :concurrently,
              name: "index_reservations_on_ended_provisioned_ends_at"
  end
end
