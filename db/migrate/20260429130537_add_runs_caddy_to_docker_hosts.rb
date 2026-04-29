# typed: true
# frozen_string_literal: true

class AddRunsCaddyToDockerHosts < ActiveRecord::Migration[7.2]
  def change
    add_column :docker_hosts, :runs_caddy, :boolean, default: true, null: false
  end
end
