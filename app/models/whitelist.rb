# typed: true
# frozen_string_literal: true

class Whitelist < ActiveRecord::Base
  extend T::Sig

  has_many :reservations, dependent: :nullify

  validates_presence_of :file

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.active
    where(hidden: false)
  end

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.ordered
    order('lower(file)')
  end

  def to_s
    file
  end
end
