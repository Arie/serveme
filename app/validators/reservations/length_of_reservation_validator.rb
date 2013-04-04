module Reservations
  class LengthOfReservationValidator < ActiveModel::Validator

    def validate(record)
      if !record.extending && record.duration > 3.hours
        record.errors.add(:ends_at, "maximum reservation time is 3 hours")
      end
    end

  end
end
