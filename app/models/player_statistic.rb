# frozen_string_literal: true
class PlayerStatistic < ActiveRecord::Base
  attr_accessible :reservation_player, :reservation_player_id, :ping, :loss, :minutes_connected
  belongs_to :reservation_player
  has_one :server,      :through => :reservation_player, :autosave => false
  has_one :reservation, :through => :reservation_player, :autosave => false
  has_one :user,        :through => :reservation_player, :autosave => false
end
