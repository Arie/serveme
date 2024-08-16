# typed: strict
# frozen_string_literal: true

class ServerConfig < ActiveRecord::Base
  extend T::Sig

  has_many :reservations, dependent: :nullify

  validates_presence_of :file

  sig { returns(ActiveRecord::Relation) }
  def self.active
    where(hidden: false)
  end

  sig { returns(ActiveRecord::Relation) }
  def self.ordered
    order('lower(file)')
  end

  sig { returns(T.nilable(String)) }
  def to_s
    file
  end
end
