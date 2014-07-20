class AddFtpPortToServers < ActiveRecord::Migration
  def change
    add_column :servers, :ftp_port, :integer, :default => 21
  end
end
