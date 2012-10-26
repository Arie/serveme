class CreateServers < ActiveRecord::Migration
  def up
    create_table :servers do |t|
      t.string :name
      t.string :path
      t.string :ip
      t.string :port
    end
  end

  def down
    drop_table :servers
  end
end
