# typed: true
# frozen_string_literal: true

class Statistic
  extend T::Sig

  sig { returns(Hash) }
  def self.top_10_users
    top_10_user_id_count_hash = Reservation.joins(:user).order(Arel.sql('count_all DESC')).limit(10).group('users.id').count
    top_10_users              = User.where(id: top_10_user_id_count_hash.keys).includes(:groups).to_a
    top_10_hash = {}
    top_10_user_id_count_hash.map do |user_id, count|
      user = top_10_users.find { |u| u.id == user_id.to_i }
      top_10_hash[user] = count
    end
    top_10_hash
  end

  sig { returns(Hash) }
  def self.top_10_servers
    Reservation.joins(:server).order(Arel.sql('count_all DESC')).limit(10).group('servers.name').count
  end

  sig { returns(Integer) }
  def self.total_reservations
    Reservation.count
  end

  sig { returns(T.any(Integer, Float, BigDecimal)) }
  def self.total_playtime_seconds
    Reservation.sum(:duration)
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def self.reservations_per_day_chart_data
    data = reservations_per_day
    {
      labels: data.map { |d| d[0] },
      values: data.map { |d| d[1] },
      title: 'Reservations',
      yAxisLabel: 'Number of Reservations'
    }
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def self.reserved_hours_per_month_chart_data
    data = reserved_hours_per_month
    {
      labels: data.map { |d| d[0] },
      values: data.map { |d| d[1] },
      title: 'Hours played',
      yAxisLabel: 'Hours played'
    }
  end

  sig { returns(T::Array[Array]) }
  def self.reservations_per_day
    Rails.cache.fetch "reservations_per_day_#{Date.current}", expires_in: 1.hour do
      Reservation.order(Arel.sql('DATE(starts_at) DESC')).limit(50).group(Arel.sql('DATE(starts_at)')).count(:id).collect do |date, count|
        [date.to_s, count]
      end.reverse
    end
  end

  sig { returns(T::Array[Array]) }
  def self.reserved_hours_per_month
    Rails.cache.fetch "reserved_hours_per_month_#{Date.current}", expires_in: 1.hour do
      result = ActiveRecord::Base.connection.execute("SELECT TO_CHAR(starts_at, 'YYYY-MM') AS year_month,
                                                      SUM(duration) as duration
                                                      FROM reservations
                                                      GROUP BY 1
                                                      ORDER BY 1")
      result.to_a.map do |duration_per_month|
        year_month = duration_per_month['year_month']
        seconds = duration_per_month['duration']
        year = year_month.split('-').first.to_i
        month = year_month.split('-').last.to_i
        date = Date.new(year, month)
        formatted_date = date.strftime('%b %Y')
        [formatted_date, (seconds.to_f / 3600.0).round]
      end
    end
  end
end
