# frozen_string_literal: true

module Reservations
  class MapIsValidValidator < ActiveModel::Validator
    def validate(record)
      return if record.first_map.blank?

      record.errors.add(:first_map, "you can't play MvM on our servers") if record.first_map.match(/mvm_.*/)
      record.errors.add(:first_map, 'does not exist') unless MapUpload.available_maps.include?(record.first_map)
    end
  end
end
