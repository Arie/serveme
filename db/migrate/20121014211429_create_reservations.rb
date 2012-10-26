class CreateReservations < ActiveRecord::Migration
  def up
    create_table :reservations do |t|
      t.integer :user_id
      t.integer :server_id
      t.date    :date
      t.string :password
      t.string :rcon
      t.string :tv_password
      t.string :tv_relaypassword
    end
  end

  def down
    drop_table :reservations
  end
end
