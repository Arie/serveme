class AddSshPortToDockerHosts < ActiveRecord::Migration[7.2]
  def change
    add_column :docker_hosts, :ssh_port, :integer, default: 22
  end
end
