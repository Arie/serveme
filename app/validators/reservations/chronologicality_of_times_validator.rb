module Reservations
  class ChronologicalityOfTimesValidator < ActiveModel::Validator

    def validate(record)
      if (record.starts_at + 30.minutes) > record.ends_at
        record.errors.add(:ends_at, "needs to be at least 30 minutes after start time")
      end
    end

  end
end
