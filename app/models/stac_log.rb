# typed: strict
# frozen_string_literal: true

class StacLog < ActiveRecord::Base
  belongs_to :reservation
end
