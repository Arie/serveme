# typed: true

class PopulateResolvedIp < ActiveRecord::Migration[7.0]
  def up
    PopulateResolvedIpsService.call
  end

  def down
    Server.update_all(resolved_ip: nil)
  end
end
