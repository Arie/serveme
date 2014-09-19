class AddPublishedToRatings < ActiveRecord::Migration
  def change
    add_column :ratings, :published, :boolean, :default => false
    add_index :ratings, :published
  end
end
