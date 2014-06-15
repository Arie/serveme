class ReservationPlayer < ActiveRecord::Base
  attr_accessible :reservation_id, :steam_uid

  belongs_to :reservation
  belongs_to :user, :primary_key => :uid, :foreign_key => :steam_uid
end
