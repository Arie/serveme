# typed: strict
# frozen_string_literal: true

class DockerHost < ActiveRecord::Base
  belongs_to :location
  validates :city, :ip, presence: true
  validates :start_port, numericality: { greater_than_or_equal_to: 27015 }
  scope :active, -> { where(active: true) }
end
