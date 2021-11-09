# frozen_string_literal: true

class CollisionFinder
  attr_reader :colliding_with, :collider

  def initialize(colliding_with, collider)
    @colliding_with = colliding_with
    @collider       = collider
  end

  def colliding_reservations
    colliding = colliding_with.where('(?, ?) OVERLAPS (reservations.starts_at, reservations.ends_at)', collider.starts_at, collider.ends_at)
    # You can't collide with yourself.
    if collider.id
      colliding.where.not(id: collider.id)
    else
      colliding
    end
  end
end
