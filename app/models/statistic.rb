class Statistic

  def self.top_10_users
    top_10_user_id_count_hash = Reservation.joins(:user).order("count_all DESC").limit(10).group("users.id").count
    top_10_users              = User.where(:id => top_10_user_id_count_hash.keys).to_a
    top_10_hash         = {}
    top_10_user_id_count_hash.map do |user_id, count|
      user = top_10_users.find { |u| u.id == user_id.to_i }
      top_10_hash[user] = count
    end
    top_10_hash
  end

  def self.top_10_servers
    Reservation.joins(:server).order("count_all DESC").limit(10).group("servers.name").count
  end

  def self.total_reservations
    Reservation.last.id if Reservation.last
  end

  def self.total_playtime_seconds
    Reservation.sum(:duration)
  end

  def self.reservations_per_day_chart
    reservations_per_time_unit("Date", reservations_per_day, "Reservations in the last 50 days")
  end

  def self.reservations_per_month_chart
    reservations_per_time_unit("Month", reservations_per_month, "Reservations per month")
  end

  def self.reservations_per_time_unit(time_unit, statistics_array, title)
    data_table = GoogleVisualr::DataTable.new
    data_table.new_column('string', time_unit)
    data_table.new_column('number', 'Reservations')
    data_table.add_rows(statistics_array)
    option = { width: 1100, height: 240, title: title, colors: ["#0044cc", "#0055cc","#0066cc","#0077cc", "0088cc"], legend: {position: 'none'} }
    GoogleVisualr::Interactive::ColumnChart.new(data_table, option)
  end

  def self.reservations_per_day
    Rails.cache.fetch "reservations_per_day_#{Date.current}", :expires_in => 1.hour do
      Reservation.order('DATE(starts_at) DESC').group("DATE(starts_at)").limit(50).count(:id).collect do |date, count|
        [date.to_s, count]
      end.reverse
    end
  end

  def self.reservations_per_month
    Rails.cache.fetch "reservations_per_month_#{Date.current}", :expires_in => 1.hour do
      result = ActiveRecord::Base.connection.execute("SELECT COUNT(*), YEAR(starts_at), MONTH(starts_at) FROM reservations GROUP BY YEAR(starts_at), MONTH(starts_at)")
      result.to_a.map do |count, year, month|
        date = Date.new(year, month)
        formatted_date = date.strftime("%b %Y")
        [formatted_date, count]
      end
    end
  end


end
