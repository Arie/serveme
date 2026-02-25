# typed: true
# frozen_string_literal: true

module Reservations
  class CloudServerConcurrencyValidator < ActiveModel::Validator
    def validate(record)
      return unless record.user
      return unless record.server.is_a?(CloudServer)

      active = record.user.active_cloud_reservation
      return unless active
      return if active.id == record.id

      record.errors.add(:server, "you already have an active cloud server")
    end
  end
end
