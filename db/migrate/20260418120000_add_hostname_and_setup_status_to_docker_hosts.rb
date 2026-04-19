# typed: true
# frozen_string_literal: true

class AddHostnameAndSetupStatusToDockerHosts < ActiveRecord::Migration[7.2]
  def up
    add_column :docker_hosts, :hostname, :string
    add_column :docker_hosts, :setup_status, :string, default: "pending", null: false
    add_index :docker_hosts, :hostname, unique: true

    execute <<~SQL
      UPDATE docker_hosts SET hostname = ip
    SQL

    change_column_null :docker_hosts, :hostname, false
  end

  def down
    remove_column :docker_hosts, :hostname
    remove_column :docker_hosts, :setup_status
  end
end
