# frozen_string_literal: true

module Reservations
  class ServerIsAvailableValidator < ActiveModel::Validator
    def validate(record)
      return unless record.server && record.collides_with_other_users_reservation?

      record.errors.add(:server_id, 'already booked in the selected timeframe')
    end
  end
end
