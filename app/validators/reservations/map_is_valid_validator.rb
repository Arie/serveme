module Reservations
  class MapIsValidValidator < ActiveModel::Validator

    def validate(record)
      if record.first_map
        if record.first_map.match(/mvm_.*/)
          record.errors.add(:first_map, "only donators can play MvM")
        end
      end
    end

  end
end
