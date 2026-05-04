# typed: true
# frozen_string_literal: true

class CreateCloudImageBuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :cloud_image_builds do |t|
      t.string  :version, null: false
      t.boolean :force_pull, null: false, default: false
      t.string  :status, null: false, default: "queued"
      t.string  :current_phase
      t.string  :digest
      t.text    :output, null: false, default: ""
      t.datetime :started_at
      t.datetime :finished_at
      t.references :triggered_by_user, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :cloud_image_builds, :created_at
  end
end
