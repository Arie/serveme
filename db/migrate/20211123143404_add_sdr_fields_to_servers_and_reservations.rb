class AddSdrFieldsToServersAndReservations < ActiveRecord::Migration[6.1]
  def change
    add_column :reservations, :sdr_ip, :string
    add_column :reservations, :sdr_port, :string
    add_column :reservations, :sdr_tv_port, :string
    add_column :servers, :sdr, :boolean, default: false
    add_column :servers, :last_sdr_ip, :string
    add_column :servers, :last_sdr_port, :string
    add_column :servers, :last_sdr_tv_port, :string
  end
end
