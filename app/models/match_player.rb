# typed: strict
# frozen_string_literal: true

class MatchPlayer < ActiveRecord::Base
  belongs_to :reservation_match
  belongs_to :user, primary_key: :uid, foreign_key: :steam_uid, optional: true
end
