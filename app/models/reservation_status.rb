# typed: true
# frozen_string_literal: true

class ReservationStatus < ActiveRecord::Base
  extend T::Sig

  belongs_to :reservation
  validates_presence_of :reservation_id

  after_create_commit -> { T.unsafe(self).broadcast_prepend_to T.unsafe(self).reservation }
  after_create_commit -> { T.unsafe(self).broadcast_replace_to T.unsafe(self).reservation, target: "reservation_status_message_#{T.unsafe(self).reservation_id}", partial: "reservations/status", locals: { reservation: T.unsafe(self).reservation } }
  after_create_commit :notify_discord

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
