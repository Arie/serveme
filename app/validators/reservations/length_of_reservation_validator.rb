module Reservations
  class LengthOfReservationValidator < ActiveModel::Validator

    def validate(record)
      user = record.user
      maximum_reservation_length = user.maximum_reservation_length
      if !record.extending && record.duration.round > maximum_reservation_length
        duration_in_words = (maximum_reservation_length / 3600.0).round
        record.errors.add(:ends_at, "maximum reservation time is #{duration_in_words} hours")
      end
    end

  end
end
