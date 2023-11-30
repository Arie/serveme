# frozen_string_literal: true

class ServerConfig < ActiveRecord::Base
  has_many :reservations, dependent: :nullify

  def self.active
    where(hidden: false)
  end

  def self.ordered
    order(:file)
  end

  def to_s
    file
  end
end
