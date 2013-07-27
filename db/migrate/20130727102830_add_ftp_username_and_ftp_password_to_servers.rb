class AddFtpUsernameAndFtpPasswordToServers < ActiveRecord::Migration
  def change
    add_column :servers, :ftp_username, :string
    add_column :servers, :ftp_password, :string
  end
end
