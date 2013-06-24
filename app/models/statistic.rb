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

  def self.reservations_per_day_chart
    data_table = GoogleVisualr::DataTable.new
    data_table.new_column('string', 'Date' )
    data_table.new_column('number', 'Reservations')
    data_table.add_rows(reservations_per_day)
    option = { width: 780, height: 240, title: 'Reservations in the last 50 days', colors: ["#0044cc", "#0055cc","#0066cc","#0077cc", "0088cc"], legend: {position: 'none'} }
    GoogleVisualr::Interactive::ColumnChart.new(data_table, option)
  end

  def self.reservations_per_day
    Rails.cache.fetch "reservations_per_day_#{Date.current}", :expires_in => 1.hour do
      Reservation.order('DATE(starts_at) DESC').group("DATE(starts_at)").limit(50).count(:id).collect do |date, count|
        [date.to_s, count]
      end
    end
  end


end
