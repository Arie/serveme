# typed: true
# frozen_string_literal: true

class CreateDockerHostSetupLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :docker_host_setup_logs do |t|
      t.references :docker_host, null: false, foreign_key: true
      t.string :step, null: false
      t.boolean :success, null: false, default: false
      t.text :output
      t.integer :exit_status
      t.timestamps
    end
    add_index :docker_host_setup_logs, [ :docker_host_id, :created_at ]
  end
end
