# frozen_string_literal: true
class Whitelist < ActiveRecord::Base
  attr_accessible :file
  has_many :reservations, :dependent => :nullify

  def self.ordered
    order(:file)
  end

  def to_s
    file
  end

end
