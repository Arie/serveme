class AddAsnFieldsToReservationPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :reservation_players, :asn_number, :integer
    add_column :reservation_players, :asn_organization, :string
    add_column :reservation_players, :asn_network, :string

    add_index :reservation_players, :asn_number
  end
end
