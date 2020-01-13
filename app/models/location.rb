# frozen_string_literal: true

class Location < ActiveRecord::Base
  has_many :servers
end
