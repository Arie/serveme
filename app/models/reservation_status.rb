class ReservationStatus < ActiveRecord::Base
  belongs_to :reservation
  attr_accessible :status
end

