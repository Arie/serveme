class CreateHiperzServerInformations < ActiveRecord::Migration
  def change
    create_table :hiperz_server_informations do |t|
      t.integer :server_id
      t.integer :hiperz_id
    end
    add_index :hiperz_server_informations, :server_id
    add_index :hiperz_server_informations, :hiperz_id
  end
end
