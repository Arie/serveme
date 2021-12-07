# frozen_string_literal: true

class ReservationStatus < ActiveRecord::Base
  belongs_to :reservation

  after_create_commit -> { broadcast_prepend_to reservation }

  def self.ordered
    order('reservation_statuses.created_at DESC')
  end
end
