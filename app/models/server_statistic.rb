class ServerStatistic < ActiveRecord::Base
  attr_accessible :server, :server_id, :reservation, :reservation_id, :cpu_usage, :fps, :number_of_players, :map_name, :traffic_in, :traffic_out
  belongs_to :server
  belongs_to :reservation
end
