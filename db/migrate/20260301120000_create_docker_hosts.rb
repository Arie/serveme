# frozen_string_literal: true

class CreateDockerHosts < ActiveRecord::Migration[8.1]
  def change
    create_table :docker_hosts do |t|
      t.references :location, null: false, foreign_key: true
      t.string :city, null: false
      t.string :ip, null: false
      t.integer :start_port, default: 27015
      t.integer :max_containers, default: 4
      t.boolean :active, default: true
      t.timestamps
    end
    add_index :docker_hosts, :active
  end
end
