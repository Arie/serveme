# frozen_string_literal: true
class ReservationPlayer < ActiveRecord::Base
  attr_accessible :reservation_id, :steam_uid, :name, :ip, :latitude, :longitude

  belongs_to :reservation
  has_one :server, :through => :reservation, :autosave => false
  belongs_to :user, :primary_key => :uid, :foreign_key => :steam_uid

  geocoded_by :ip
  before_save :geocode, :if => :ip_changed?
end
