# typed: false
# frozen_string_literal: true

class CreateSiteSettings < ActiveRecord::Migration[8.0]
  def up
    create_table :site_settings do |t|
      t.string :key, null: false
      t.string :value
      t.timestamps
    end

    add_index :site_settings, :key, unique: true

    defaults = case SITE_HOST
    when "au.serveme.tf"
      {
        "free_server_limit" => 5,
        "always_enable_plugins" => "true",
        "always_enable_demos_tf" => "true",
        "show_democheck" => "false"
      }
    when "na.serveme.tf"
      {
        "free_server_limit" => 10,
        "always_enable_plugins" => "true",
        "always_enable_demos_tf" => "true",
        "show_democheck" => "true"
      }
    else
      {
        "free_server_limit" => 10,
        "always_enable_plugins" => "true",
        "always_enable_demos_tf" => "true",
        "show_democheck" => "false"
      }
    end

    defaults.each do |key, value|
      execute "INSERT INTO site_settings (key, value, created_at, updated_at) VALUES (#{connection.quote(key)}, #{connection.quote(value)}, NOW(), NOW())"
    end
  end

  def down
    drop_table :site_settings
  end
end
