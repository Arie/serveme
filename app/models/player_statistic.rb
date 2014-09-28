class PlayerStatistic < ActiveRecord::Base
  attr_accessible :server, :server_id, :reservation, :reservation_id, :name, :steam_uid, :ping, :loss, :minutes_connected, :ip
  belongs_to :server
  belongs_to :reservation
  belongs_to :user, :primary_key => :uid, :foreign_key => :steam_uid
  geocoded_by :ip
  before_save :geocode, :if => :ip_changed?

  delegate :name, :to => :server, :prefix => true
end
