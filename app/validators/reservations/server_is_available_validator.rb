module Reservations
  class ServerIsAvailableValidator < ActiveModel::Validator

    def validate(record)
      if record.server && record.collides_with_other_users_reservation?
        record.errors.add(:server_id,  "already booked in the selected timeframe")
      end
    end

  end
end
