# typed: strict
# frozen_string_literal: true

class ReservationManager
  extend T::Sig

  sig { returns(Reservation) }
  attr_reader :reservation

  delegate :server, to: :reservation, prefix: false

  sig { params(reservation: Reservation).void }
  def initialize(reservation)
    @reservation = reservation
  end

  sig { returns(T.untyped) }
  def start_reservation
    return if server.is_a?(CloudServer)

    if previous_reservation_ended_fully?
      reservation.reservation_statuses.create!(status: "Starting")
      manage_reservation(:start)
    else
      reservation.update_attribute(:start_instantly, false)
      reservation.reservation_statuses.create!(status: "Waiting for other reservation on server to end fully")
    end
  end

  sig { returns(T.nilable(String)) }
  def end_reservation
    return if reservation.ended? || reservation.status == "Ending"

    # The cheap guard above is a non-atomic check-then-act: end_reservation is
    # triggered from several places (CronWorker#end_past_reservations,
    # ActiveReservationsCheckerWorker, the Discord end command, ...) and two of
    # them can both pass it before either persists the "Ending" transition,
    # double-firing after_end_reservation_steps (duplicate Discord announcements,
    # LogScan/MatchStats, CloudServerDestroy). Serialize the transition per
    # reservation and re-check under the lock so only one caller claims it.
    return unless claim_ending

    manage_reservation(:end)
  end

  sig { returns(T.nilable(String)) }
  def update_reservation
    manage_reservation(:update)
  end

  sig { params(action: Symbol).returns(T.nilable(String)) }
  def manage_reservation(action)
    ReservationWorker.perform_async(reservation.id, action.to_s)
  end

  private

  sig { returns(T::Boolean) }
  def claim_ending
    claimed = T.let(false, T::Boolean)
    $lock.synchronize("reservation-end-#{reservation.id}", retries: 7, initial_wait: 0.5, expiry: 2.minutes) do
      reservation.reload
      unless reservation.ended? || reservation.reservation_statuses.exists?(status: "Ending")
        reservation.reservation_statuses.create!(status: "Ending")
        claimed = true
      end
    end
    claimed
  end

  sig { returns(T::Boolean) }
  def previous_reservation_ended_fully?
    Reservation.where.not(id: reservation.id)
      .where(server_id: reservation.server_id, ended: false)
      .where(starts_at: ...Time.current)
      .where(ends_at: (15.minutes.ago..))
      .none?
  end
end
