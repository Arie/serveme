# frozen_string_literal: true

module Reservations
  class MapIsValidValidator < ActiveModel::Validator
    def validate(record)
      record.errors.add(:first_map, "you can't play MvM on our servers") if record.first_map&.match(/mvm_.*/)
    end
  end
end
