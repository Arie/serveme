# frozen_string_literal: true
module Reservations
  class GameyeLocationSelectedValidator < ActiveModel::Validator

    def validate(record)
      if GameyeServer.location_keys.include?(record.gameye_location)
        location =  GameyeServer.locations.find {|loc| loc[:id]  == record.gameye_location }
        if CollisionFinder.new(Reservation.where(:gameye_location => location[:id]), record).colliding_reservations.size >= location[:concurrency_limit]
          record.errors.add(:gameye_location, "server location is full, please choose another location")
        end
      else
        record.errors.add(:gameye_location, "server location is required")
      end
    end
  end
end
