# frozen_string_literal: true

class BackfillRemoteDockerCloudServerNames < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    hosts_by_id = execute("SELECT id, city, hostname FROM docker_hosts").to_a.each_with_object({}) do |row, h|
      h[row["id"].to_s] = row
    end

    servers = execute(<<~SQL).to_a
      SELECT id, cloud_location, name
      FROM servers
      WHERE type = 'CloudServer' AND cloud_provider = 'remote_docker'
    SQL

    updated = 0
    skipped = 0
    servers.each do |server|
      host = hosts_by_id[server["cloud_location"].to_s]
      if host.nil?
        skipped += 1
        next
      end

      new_name = "#{host['city']} (#{host['hostname']})"
      next if server["name"] == new_name

      execute(
        ActiveRecord::Base.sanitize_sql([
          "UPDATE servers SET name = ? WHERE id = ?",
          new_name, server["id"]
        ])
      )
      updated += 1
    end

    say "Backfilled #{updated} remote_docker CloudServer names (skipped #{skipped} with missing docker_host)"
  end

  def down
    # Irreversible: previous names depended on the SITE_HOST value at the
    # time of creation across multiple regions and cannot be reconstructed.
  end
end
