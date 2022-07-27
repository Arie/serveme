class EnsureUtcTimestamps < ActiveRecord::Migration[7.0]
  def switcheroo(table, columns)
    puts "Doing the switcheroo for #{table} and columns #{columns.join(', ')}"

    columns.each do |column|
      add_column table, :"#{column}_utc", :datetime
    end

    fill_columns_statement = columns.map do |column|
      "#{column}_utc = #{column} at time zone 'UTC'"
    end.join(', ')

    execute("
      UPDATE #{table} SET #{fill_columns_statement};
    ")

    columns.each do |column|
      execute("
        ALTER TABLE #{table} ALTER COLUMN #{column} TYPE TIMESTAMP without time zone USING #{column}_utc;
      ")
      remove_column(table, "#{column}_utc")
    end
  end

  def change
    switcheroo(:group_servers, %i[created_at updated_at])
    switcheroo(:group_users, %i[created_at updated_at expires_at])
    switcheroo(:groups, %i[created_at updated_at])
    switcheroo(:locations, %i[created_at updated_at])
    switcheroo(:log_uploads, %i[created_at updated_at])
    switcheroo(:map_uploads, %i[created_at updated_at])
    switcheroo(:paypal_orders, %i[created_at updated_at])
    switcheroo(:player_statistics, %i[created_at updated_at])
    switcheroo(:reservation_statuses, %i[created_at updated_at])
    switcheroo(:reservations, %i[created_at updated_at starts_at ends_at])
    switcheroo(:server_configs, %i[created_at updated_at])
    switcheroo(:server_statistics, %i[created_at updated_at])
    switcheroo(:servers, %i[created_at updated_at])
    switcheroo(:users, %i[created_at updated_at reset_password_sent_at remember_created_at current_sign_in_at last_sign_in_at])
    switcheroo(:whitelists, %i[created_at updated_at])
  end
end
