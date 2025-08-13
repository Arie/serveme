class UpdateMoreServerCoordinates < ActiveRecord::Migration[8.0]
  def up
    # Chicago servers
    Server.where(ip: [ 'chi5.serveme.tf', '14.1.30.218' ]).update_all(
      latitude: 41.8500,
      longitude: -87.6500
    )

    Server.where(ip: [ 'chi2.serveme.tf', '104.128.50.71' ]).update_all(
      latitude: 41.8500,
      longitude: -87.6500
    )

    Server.where(ip: [ 'chi3.serveme.tf', '108.181.63.191' ]).update_all(
      latitude: 41.8500,
      longitude: -87.6500
    )

    # Dallas server
    Server.where(ip: [ 'dal3.serveme.tf', '199.71.214.77' ]).update_all(
      latitude: 32.7831,
      longitude: -96.8067
    )

    # Kansas City server
    Server.where(ip: [ 'ks3.serveme.tf', '198.204.226.242' ]).update_all(
      latitude: 39.0997,
      longitude: -94.5786
    )

    # Rotterdam server
    Server.where(ip: [ 'bolus.fakkelbrigade.eu', '5.200.27.207' ]).update_all(
      latitude: 51.9291,
      longitude: 4.4203
    )

    Rails.cache.clear
  end

  def down
    puts "This migration cannot be reversed as the previous coordinates were incorrect"
  end
end
