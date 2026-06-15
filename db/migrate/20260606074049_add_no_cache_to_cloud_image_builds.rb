# typed: true
# frozen_string_literal: true

class AddNoCacheToCloudImageBuilds < ActiveRecord::Migration[8.1]
  def change
    add_column :cloud_image_builds, :no_cache, :boolean, null: false, default: false
  end
end
