# frozen_string_literal: true
class HiperzServerInformation < ActiveRecord::Base
  belongs_to :server
  validates_presence_of :hiperz_id, :server_id
end
