# typed: strict
# frozen_string_literal: true

class ReservationStatus < ActiveRecord::Base
  extend T::Sig

  belongs_to :reservation
  validates_presence_of :reservation_id

  after_create_commit -> {
    T.bind(self, ReservationStatus)
    BetaBroadcast.prepend reservation, target: "reservation_statuses", partial: "reservation_statuses/reservation_status", locals: { reservation_status: self }
  }
  after_create_commit -> {
    T.bind(self, ReservationStatus)
    BetaBroadcast.replace reservation, target: "reservation_status_message_#{reservation_id}", partial: "reservations/status", locals: { reservation: reservation }
  }
  after_create_commit :notify_discord
  after_update_commit -> {
    T.bind(self, ReservationStatus)
    BetaBroadcast.replace reservation, target: ActionView::RecordIdentifier.dom_id(self), partial: "reservation_statuses/reservation_status", locals: { reservation_status: self }
  }
  after_update_commit -> {
    T.bind(self, ReservationStatus)
    BetaBroadcast.replace reservation, target: "reservation_status_message_#{reservation_id}", partial: "reservations/status", locals: { reservation: reservation }
  }

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.ordered
    order(created_at: :desc)
  end

  private

  sig { void }
  def notify_discord
    return unless T.unsafe(reservation).discord_channel_id.present?

    DiscordReservationUpdateWorker.perform_async(reservation_id)
  end
end
