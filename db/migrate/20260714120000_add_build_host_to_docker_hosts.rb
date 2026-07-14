# typed: true
# frozen_string_literal: true

class AddBuildHostToDockerHosts < ActiveRecord::Migration[8.1]
  def up
    add_column :docker_hosts, :build_host, :boolean, default: false, null: false
    DockerHost.reset_column_information
    DockerHost.where(hostname: "new.fakkelbrigade.eu").update_all(build_host: true)
  end

  def down
    remove_column :docker_hosts, :build_host
  end
end
