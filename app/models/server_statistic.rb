# frozen_string_literal: true

class ServerStatistic < ActiveRecord::Base
  belongs_to :reservation
  belongs_to :server
end
