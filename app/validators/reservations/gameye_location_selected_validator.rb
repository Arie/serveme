# frozen_string_literal: true
module Reservations
  class GameyeLocationSelectedValidator < ActiveModel::Validator

    def validate(record)
      unless GameyeServer.location_keys.include?(record.gameye_location)
        record.errors.add(:gameye_location, "server location is required")
      end
    end
  end
end
