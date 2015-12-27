# frozen_string_literal: true
class CollisionFinder

  attr_reader :colliding_with, :collider

  def initialize(colliding_with, collider)
    @colliding_with = colliding_with
    @collider       = collider
  end


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
  def front_rear_and_internal_collisions
    colliding_with.where('reservations.starts_at' => range) + colliding_with.where('reservations.ends_at' => range)
  end

  # ------XXXXXX--------
  # ---YYYYYYYYYYYY-----
  def overlap_collisions
    colliding_with.where('reservations.starts_at < ? AND reservations.ends_at > ?', starts_at, ends_at)
  end

  def range
    @range ||= starts_at..ends_at
  end

  def starts_at
    collider.starts_at
  end

  def ends_at
    collider.ends_at
  end

end
