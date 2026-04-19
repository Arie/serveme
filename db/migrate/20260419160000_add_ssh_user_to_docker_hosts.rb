class AddSshUserToDockerHosts < ActiveRecord::Migration[7.2]
  def change
    add_column :docker_hosts, :ssh_user, :string, default: "tf2"
  end
end
