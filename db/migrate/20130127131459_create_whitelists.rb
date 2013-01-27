class CreateWhitelists < ActiveRecord::Migration
  def up
    create_table :whitelists do |t|
      t.string :file
      t.timestamps
    end
  end

  def down
    drop_table :whitelists
  end
end
