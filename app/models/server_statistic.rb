# typed: strict
# frozen_string_literal: true

class ServerStatistic < ActiveRecord::Base
  extend T::Sig

  belongs_to :reservation
  belongs_to :server

  after_create :notify_discord

  private

  sig { void }
  def notify_discord
    return unless T.unsafe(reservation).discord_channel_id.present?

    DiscordReservationUpdateWorker.perform_async(reservation_id)
  end
end
