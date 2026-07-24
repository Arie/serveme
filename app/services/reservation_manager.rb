# typed: strict
# frozen_string_literal: true

class ReservationManager
  extend T::Sig

  # A "Starting"/"Ending" claim row older than this is treated as abandoned, so a
  # later trigger may re-claim a transition whose worker died mid-flight. Well
  # above ReservationWorker's ~3-minute retry window, so a live job never overlaps.
  CLAIM_TTL = T.let(15.minutes, ActiveSupport::Duration)

  sig { returns(Reservation) }
  attr_reader :reservation

  delegate :server, to: :reservation, prefix: false

  sig { params(reservation: Reservation).void }
  def initialize(reservation)
    @reservation = reservation
  end

  sig { returns(T.untyped) }
  def start_reservation
    return if server&.cloud?

    if previous_reservation_ended_fully?
      manage_reservation(:start) if claim_starting
    else
      reservation.update_attribute(:start_instantly, false)
      reservation.reservation_statuses.create!(status: "Waiting for other reservation on server to end fully")
    end
  end

  sig { returns(T.nilable(String)) }
  def end_reservation
    return if reservation.ended?

    # Serialize the transition per reservation so concurrent triggers don't
    # double-fire after_end_reservation_steps; the claim expires after CLAIM_TTL.
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
  def claim_starting
    claim_transition("reservation-start-#{reservation.id}", "Starting") do
      reservation.provisioned?
    end
  end

  sig { returns(T::Boolean) }
  def claim_ending
    claim_transition("reservation-end-#{reservation.id}", "Ending") do
      reservation.ended?
    end
  end

  sig { params(lock_name: String, status: String, already_done: T.proc.returns(T::Boolean)).returns(T::Boolean) }
  def claim_transition(lock_name, status, &already_done)
    claimed = T.let(false, T::Boolean)
    $lock.synchronize(lock_name, retries: 7, initial_wait: 0.5, expiry: 2.minutes) do
      reservation.reload
      unless already_done.call || reservation.reservation_statuses.exists?(status: status, created_at: CLAIM_TTL.ago..)
        reservation.reservation_statuses.create!(status: status)
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
