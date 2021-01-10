# frozen_string_literal: true

module Reservations
  class LengthOfReservationValidator < ActiveModel::Validator
    def validate(record)
      user = record.user
      maximum_reservation_length = if record.gameye?
                                     3.hours
                                   else
                                     user.maximum_reservation_length
                                   end

      return unless !record.extending && record.duration.round > maximum_reservation_length

      duration_in_hours = (maximum_reservation_length / 3600.0).round
      message = "maximum reservation time is #{duration_in_hours} hours"

      message += ', you can extend if you run out of time' unless record.gameye?
      record.errors.add(:ends_at, message)
    end
  end
end
