module Reservations
  class ReservableByUserValidator < ActiveModel::Validator

    def validate(record)
      unless Server.active.reservable_by_user(record.user).map(&:id).include?(record.server_id)
        record.errors.add(:server_id, "is not available for you")
      end
    end

  end
end
