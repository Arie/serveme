# frozen_string_literal: true

class GroupServer < ActiveRecord::Base
  belongs_to :server
  belongs_to :group
end
