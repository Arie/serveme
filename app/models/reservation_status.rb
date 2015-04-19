class ReservationStatus < ActiveRecord::Base
  belongs_to :reservation
  attr_accessible :status

  def self.ordered
    order("reservation_statuses.created_at DESC")
  end
end

