# frozen_string_literal: true

class ReservationStatus < ActiveRecord::Base
  belongs_to :reservation
  validates_presence_of :reservation_id

  after_create_commit -> { broadcast_prepend_to reservation }
  after_create_commit -> { broadcast_replace_to reservation, target: "reservation_status_message_#{reservation_id}", partial: 'reservations/status', locals: { reservation: reservation } }

  def self.ordered
    order('reservation_statuses.created_at DESC')
  end
end
