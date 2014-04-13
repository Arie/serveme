module Reservations
  class ChronologicalityOfTimesValidator < ActiveModel::Validator

    def validate(record)
      if validatable?(record) && (record.starts_at + 30.minutes) > record.ends_at
        record.errors.add(:ends_at, "needs to be at least 30 minutes after start time")
      end
    end

    def validatable?(record)
      record.starts_at && record.ends_at
    end

  end
end
