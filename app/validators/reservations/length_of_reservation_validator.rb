module Reservations
  class LengthOfReservationValidator < ActiveModel::Validator

    def validate(record)
      user = record.user
      maximum_reservation_length = user.maximum_reservation_length
      if !record.extending && record.duration > maximum_reservation_length
        duration_in_words = Duration.new(maximum_reservation_length).format("%h %~h")
        record.errors.add(:ends_at, "maximum reservation time is #{duration_in_words}")
      end
    end

  end
end
