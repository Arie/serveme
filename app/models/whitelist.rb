# typed: true
# frozen_string_literal: true

class Whitelist < ActiveRecord::Base
  extend T::Sig

  has_many :reservations, dependent: :nullify

  validates_presence_of :file

  scope :active, -> { where(hidden: false) }

  scope :ordered, -> { order("lower(file)") }

  sig { returns(T.nilable(String)) }
  def to_s
    file
  end
end
