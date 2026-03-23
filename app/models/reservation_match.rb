# typed: strict
# frozen_string_literal: true

class ReservationMatch < ActiveRecord::Base
  belongs_to :reservation
  has_many :match_players, dependent: :destroy
end
