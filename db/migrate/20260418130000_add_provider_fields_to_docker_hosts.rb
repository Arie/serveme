# typed: false
# frozen_string_literal: true

class AddProviderFieldsToDockerHosts < ActiveRecord::Migration[8.0]
  def change
    add_column :docker_hosts, :provider, :string
    add_column :docker_hosts, :provider_server_id, :string
    add_column :docker_hosts, :provider_location, :string
    change_column_null :docker_hosts, :ip, true
  end
end
