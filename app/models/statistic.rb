# frozen_string_literal: true
class Statistic

  def self.top_10_users
    top_10_user_id_count_hash = Reservation.joins(:user).order(Arel.sql("count_all DESC")).limit(10).group("users.id").count
    top_10_users              = User.where(:id => top_10_user_id_count_hash.keys).includes(:groups).to_a
    top_10_hash         = {}
    top_10_user_id_count_hash.map do |user_id, count|
      user = top_10_users.find { |u| u.id == user_id.to_i }
      top_10_hash[user] = count
    end
    top_10_hash
  end

  def self.top_10_servers
    Reservation.joins(:server).order(Arel.sql("count_all DESC")).limit(10).group("servers.name").count
  end

  def self.total_reservations
    Reservation.count
  end

  def self.total_playtime_seconds
    Reservation.sum(:duration)
  end

  def self.reservations_per_day_chart
    reservations_per_time_unit("Date", reservations_per_day, "Reservations in the last 50 days")
  end

  def self.reserved_hours_per_month_chart
    reservations_per_time_unit("Month", reserved_hours_per_month, "Hours played", "Hours played")
  end

  def self.reservations_per_time_unit(time_unit, statistics_array, title, bar_title = "Reservation")
    data_table = GoogleVisualr::DataTable.new
    data_table.new_column('string', time_unit)
    data_table.new_column('number', bar_title)
    data_table.add_rows(statistics_array)
    option = { width: 1100, height: 240, title: title, colors: ["#0044cc", "#0055cc","#0066cc","#0077cc", "0088cc"], legend: {position: 'none'} }
    GoogleVisualr::Interactive::ColumnChart.new(data_table, option)
  end

  def self.reservations_per_day
    Rails.cache.fetch "reservations_per_day_#{Date.current}", :expires_in => 1.hour do
      Reservation.order(Arel.sql('DATE(starts_at) DESC')).group(Arel.sql("DATE(starts_at)")).limit(50).count(:id).collect do |date, count|
        [date.to_s, count]
      end.reverse
    end
  end

  def self.reserved_hours_per_month
   Rails.cache.fetch "reserved_hours_per_month_#{Date.current}", :expires_in => 1.hour do
      result = ActiveRecord::Base.connection.execute("SELECT TO_CHAR(starts_at, 'YYYY-MM') AS year_month,
                                                      SUM(duration) as duration
                                                      FROM reservations
                                                      GROUP BY 1
                                                      ORDER BY 1")
      result.to_a.map do |duration_per_month|
        year_month= duration_per_month["year_month"]
        seconds   = duration_per_month["duration"]
        year = year_month.split("-").first.to_i
        month = year_month.split("-").last.to_i
        date = Date.new(year, month)
        formatted_date = date.strftime("%b %Y")
        [formatted_date, (seconds.to_f / 3600.0).round]
      end
   end
  end


end
