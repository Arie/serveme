class CreateWhitelists < ActiveRecord::Migration[4.2]
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
