# typed: true
# frozen_string_literal: true

class ReservationManager
  extend T::Sig

  attr_reader :reservation

  delegate :server, to: :reservation, prefix: false

  def initialize(reservation)
    @reservation = reservation
  end

  def start_reservation
    if previous_reservation_ended_fully?
      reservation.reservation_statuses.create!(status: "Starting")
      manage_reservation(:start)
    else
      reservation.update_attribute(:start_instantly, false)
      reservation.reservation_statuses.create!(status: "Waiting for other reservation on server to end fully")
    end
  end

  def end_reservation
    return if reservation.ended? || reservation.status == "Ending"

    reservation.reservation_statuses.create!(status: "Ending")
    manage_reservation(:end)
  end

  def update_reservation
    manage_reservation(:update)
  end

  sig { params(action: Symbol).returns(T.nilable(String)) }
  def manage_reservation(action)
    ReservationWorker.perform_async(reservation.id, action.to_s)
  end

  private

  def previous_reservation_ended_fully?
    Reservation.where.not(id: reservation.id)
      .where(server_id: reservation.server_id, ended: false)
      .where(starts_at: ...Time.current)
      .where(ends_at: (15.minutes.ago..))
      .none?
  end
end
