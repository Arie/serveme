class Location < ActiveRecord::Base
  attr_accessible :flag, :name
  has_many :servers
end
