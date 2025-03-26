# typed: true
# frozen_string_literal: true

module Reservations
  class ServerIsAvailableValidator < ActiveModel::Validator
    def validate(record)
      return unless record.server && (record.collides_with_other_users_reservation? || record.collides_with_own_reservation_on_same_server?)

      record.errors.add(:server_id, "already booked in the selected timeframe")
    end
  end
end
