class ServerStatistic < ActiveRecord::Base
  attr_accessible :reservation, :reservation_id, :server, :server_id, :cpu_usage, :fps, :number_of_players, :map_name, :traffic_in, :traffic_out
  belongs_to :reservation
  belongs_to :server
end
