# frozen_string_literal: true

module Reservations
  class LengthOfReservationValidator < ActiveModel::Validator
    def validate(record)
      return unless !record.extending && record.duration.round > maximum_reservation_length(record)

      duration_in_hours = (maximum_reservation_length(record) / 3600.0).round
      message = "maximum reservation time is #{duration_in_hours} hours"

      record.errors.add(:ends_at, message)
    end

    private

    def maximum_reservation_length(record)
      if record.gameye?
        3.hours
      else
        record.user.maximum_reservation_length
      end
    end
  end
end
