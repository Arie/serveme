class Statistic

  def self.recent_reservations
    Reservation.order('created_at DESC').limit(100)
  end

  def self.top_10
    use_count_per_user  = Version.where(:event => 'create').group(:whodunnit).count
    top_10_array        = use_count_per_user.sort_by {|user, count| count }.reverse.first(10)
    users               = User.all.to_a
    top_10_hash         = {}
    top_10_array.each do |user_id, count|
      user = users.select { |u| u.id == user_id.to_i }.first
      top_10_hash[user] = count
    end
    top_10_hash
  end

end
