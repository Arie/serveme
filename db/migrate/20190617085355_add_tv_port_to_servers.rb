class AddTvPortToServers < ActiveRecord::Migration[5.2]
  class Server < ActiveRecord::Base
    self.inheritance_column = nil
  end
  def up
    add_column :servers, :tv_port, :string
    Server.reset_column_information
    Server.all.each do |s|
      s.update_attribute(:tv_port, s.port.to_i + 5)
    end
  end
  def down
    remove_column :servers, :tv_port
  end
end
