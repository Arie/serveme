module Reservations
  class MapIsValidValidator < ActiveModel::Validator

    def validate(record)
      if record.first_map
        if record.first_map.match(/mvm_.*/)
          record.errors.add(:first_map, "you can't play MvM on our servers")
        elsif record.first_map == "ctf_turbine"
          record.errors.add(:first_map, "you can't pick ctf_turbine as first map")
        end
      end
    end

  end
end
