module Reservations
  class StartsNotTooFarInPastValidator < ActiveModel::Validator

    def validate(record)
      if record.starts_at && record.starts_at < 15.minutes.ago
        record.errors.add(:starts_at, "can't be more than 15 minutes in the past")
      end
    end

  end
end
