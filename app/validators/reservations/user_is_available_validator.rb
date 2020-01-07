# frozen_string_literal: true

module Reservations
  class UserIsAvailableValidator < ActiveModel::Validator
    def validate(record)
      if record.collides_with_own_reservation?
        msg = 'you already have a reservation in this timeframe'
        record.errors.add(:starts_at, msg)
        record.errors.add(:ends_at,   msg)
      end
    end
  end
end
