class AddCoordinatesToDockerHosts < ActiveRecord::Migration[7.2]
  def change
    add_column :docker_hosts, :latitude, :float
    add_column :docker_hosts, :longitude, :float
  end
end
