# frozen_string_literal: true
module Reservations
  class LengthOfReservationValidator < ActiveModel::Validator

    def validate(record)
      user = record.user
      if record.gameye?
        maximum_reservation_length = 3.hours
      else
        maximum_reservation_length = user.maximum_reservation_length
      end
      duration_in_hours = (maximum_reservation_length / 3600.0).round
      message = "maximum reservation time is #{duration_in_hours} hours"

      if !record.extending && record.duration.round > maximum_reservation_length
        if !record.gameye?
          message = message + ", you can extend if you run out of time"
        end
        record.errors.add(:ends_at, message)
      end
    end

  end
end
