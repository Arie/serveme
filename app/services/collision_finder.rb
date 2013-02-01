class CollisionFinder

  attr_reader :colliding_with, :collider

  def initialize(colliding_with, collider)
    @colliding_with = colliding_with
    @collider       = collider
  end


  def colliding_reservations
    front_rear_and_complete_colliding = (colliding_with.reservations.where(:starts_at => range) + colliding_with.reservations.where(:ends_at => range))
    internal_colliding                = colliding_with.reservations.where('starts_at < ? AND ends_at > ?', starts_at, ends_at)
    colliding = (front_rear_and_complete_colliding + internal_colliding).uniq
    #If collider is an existing record, remove it from the colliding ones
    if collider.persisted?
      colliding.reject { |r| r.id == collider.id }
    else
      colliding
    end
  end

  private

  def range
    starts_at..ends_at
  end

  def starts_at
    collider.starts_at
  end

  def ends_at
    collider.ends_at
  end

end
