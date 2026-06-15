# typed: strict
# frozen_string_literal: true

class CollisionFinder
  extend T::Sig

  sig { returns(ActiveRecord::Relation) }
  attr_reader :colliding_with

  sig { returns(Reservation) }
  attr_reader :collider

  sig { params(colliding_with: ActiveRecord::Relation, collider: Reservation).void }
  def initialize(colliding_with, collider)
    @colliding_with = colliding_with
    @collider       = collider
    @range = T.let(nil, T.nilable(T::Range[T.nilable(ActiveSupport::TimeWithZone)]))
  end

  sig { returns(T::Array[Reservation]) }
  def colliding_reservations
    colliding = (front_rear_and_internal_collisions + overlap_collisions).uniq
    # You can't collide with yourself.
    if collider.persisted?
      colliding.reject { |r| r.id == collider.id }
    else
      colliding
    end
  end

  private

  # ------XXXXXX--------
  # ----YYYY------------
  #
  # ------XXXXXX--------
  # ---------YYYY-------
  #
  # ----XXXXXXXXXXXX----
  # -------YYYYY--------
  sig { returns(T::Array[Reservation]) }
  def front_rear_and_internal_collisions
    colliding_with.where(ended: false).where("reservations.starts_at" => range) + colliding_with.where("reservations.ends_at" => range)
  end

  # ------XXXXXX--------
  # ---YYYYYYYYYYYY-----
  sig { returns(ActiveRecord::Relation) }
  def overlap_collisions
    colliding_with.where(ended: false).where(starts_at: ..ends_at).where(ends_at: starts_at..)
  end

  sig { returns(T::Range[T.nilable(ActiveSupport::TimeWithZone)]) }
  def range
    @range ||= starts_at..ends_at
  end

  sig { returns(T.nilable(ActiveSupport::TimeWithZone)) }
  def starts_at
    collider.starts_at
  end

  sig { returns(T.nilable(ActiveSupport::TimeWithZone)) }
  def ends_at
    collider.ends_at
  end
end
