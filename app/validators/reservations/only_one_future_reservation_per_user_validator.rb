module Reservations
  class OnlyOneFutureReservationPerUserValidator < ActiveModel::Validator

    def validate(record)
      if record.user
        future_reservations = record.user.reservations.future
        if (future_reservations - [record]).any?
          record.errors.add(:starts_at, "you can only have 1 planned reservation at a time if you're not a donator")
        end
      end
    end

  end
end
