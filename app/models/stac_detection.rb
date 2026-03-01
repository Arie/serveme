# typed: true
# frozen_string_literal: true

class StacDetection < ActiveRecord::Base
  belongs_to :reservation
  belongs_to :stac_log, optional: true

  FILTERED_TYPES = /\ASilent ?Aim|Trigger ?Bot|CmdNum SPIKE|Aimsnap\z/i
  MIN_COUNT_THRESHOLD = 3
end
