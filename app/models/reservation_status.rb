# frozen_string_literal: true

class ReservationStatus < ActiveRecord::Base
  belongs_to :reservation

  def self.ordered
    order('reservation_statuses.created_at DESC')
  end
end
