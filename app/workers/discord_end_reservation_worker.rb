# typed: false
# frozen_string_literal: true

class DiscordEndReservationWorker
  include Sidekiq::Worker

  sidekiq_options queue: :discord, retry: 3

  def perform(reservation_id, discord_interaction_token)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation

    reservation.update(end_instantly: true)
    reservation.end_reservation

    # Update the original interaction response
    DiscordApiClient.update_interaction_response(
      interaction_token: discord_interaction_token,
      content: ":white_check_mark: Reservation ##{reservation_id} ended"
    )
  rescue StandardError => e
    Rails.logger.error "DiscordEndReservationWorker error: #{e.message}"
    begin
      DiscordApiClient.update_interaction_response(
        interaction_token: discord_interaction_token,
        content: ":x: Failed to end reservation: #{e.message}"
      )
    rescue StandardError
      # Ignore if we can't update the response
    end
  end
end
