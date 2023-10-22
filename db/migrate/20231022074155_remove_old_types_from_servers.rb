class RemoveOldTypesFromServers < ActiveRecord::Migration[7.1]
  def change
    Server.where(type: %w[GameyeServer SimraiServer HiperzServer]).update_all(type: 'LocalServer')
  end
end
