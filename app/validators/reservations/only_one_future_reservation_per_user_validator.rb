# frozen_string_literal: true

module Reservations
  class OnlyOneFutureReservationPerUserValidator < ActiveModel::Validator
    def validate(record)
      return unless record.user

      future_reservations = record.user.reservations.future
      record.errors.add(:starts_at, "you can only have 1 planned reservation at a time if you're not a donator") if (future_reservations - [record]).any?
    end
  end
end
