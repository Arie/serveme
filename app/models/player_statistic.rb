# frozen_string_literal: true
class PlayerStatistic < ActiveRecord::Base
  belongs_to :reservation_player
  has_one :server,      :through => :reservation_player, :autosave => false
  has_one :reservation, :through => :reservation_player, :autosave => false
  has_one :user,        :through => :reservation_player, :autosave => false
end
