class UpdateServerCoordinatesFromOverrides < ActiveRecord::Migration[8.0]
  def up
    Server.where(ip: 'monika.fakkelbrigade.eu').update_all(
      latitude: 50.11552,
      longitude: 8.68417
    )

    Server.where(ip: 'new.fakkelbrigade.eu').update_all(
      latitude: 50.4779,
      longitude: 12.3716
    )

    Rails.cache.clear
  end

  def down
    puts "This migration cannot be reversed as the previous coordinates were incorrect"
  end
end
