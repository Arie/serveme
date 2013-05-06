class Statistic

  def self.top_10_users
    top_10_user_id_count_hash = Reservation.joins(:user).order("count_all DESC").limit(10).count(group: "users.id")
    top_10_users              = User.where(:id => top_10_user_id_count_hash.keys).to_a
    top_10_hash         = {}
    top_10_user_id_count_hash.map do |user_id, count|
      user = top_10_users.find { |u| u.id == user_id.to_i }
      top_10_hash[user] = count
    end
    top_10_hash
  end

  def self.top_10_servers
    Reservation.joins(:server).order("count_all DESC").limit(10).count(group: "servers.name")
  end

  def self.total_reservations
    Reservation.last.id if Reservation.last
  end

  def self.total_playtime_seconds
    Reservation.scoped.sum(&:duration)
  end

end
