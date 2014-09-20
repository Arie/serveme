module ServerRatings

  def rating
    return 1.0 if bad_ratings.none?
    good_ratings.count.to_f / published_ratings.count.to_f
  end

  private

  def published_ratings
    ratings.published
  end

  def good_ratings
    published_ratings.good
  end

  def bad_ratings
    published_ratings.bad
  end

end
