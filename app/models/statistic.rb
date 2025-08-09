# typed: true
# frozen_string_literal: true

class Statistic
  extend T::Sig

  sig { returns(Hash) }
  def self.top_10_users
    Rails.cache.fetch "top_10_users_#{Date.current}", expires_in: 6.hours do
      if User.column_names.include?("reservations_count")
        top_users = User.includes(:groups)
                        .where("reservations_count > 0")
                        .order(reservations_count: :desc)
                        .limit(10)

        top_users.each_with_object({}) do |user, hash|
          hash[user] = user.reservations_count
        end
      else
        top_users = User.joins(:reservations)
                        .includes(:groups)
                        .group("users.id")
                        .select("users.*, COUNT(reservations.id) as reservation_count")
                        .order(Arel.sql("COUNT(reservations.id) DESC"))
                        .limit(10)

        top_users.each_with_object({}) do |user, hash|
          hash[user] = user.read_attribute(:reservation_count)
        end
      end
    end
  end

  sig { returns(Hash) }
  def self.top_10_servers
    Rails.cache.fetch "top_10_servers_#{Date.current}", expires_in: 6.hours do
      Reservation.joins(:server)
                 .group("servers.name")
                 .order(Arel.sql("COUNT(*) DESC"))
                 .limit(10)
                 .count
    end
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
      title: "Reservations",
      yAxisLabel: "Number of Reservations"
    }
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def self.reserved_hours_per_month_chart_data
    data = reserved_hours_per_month
    {
      labels: data.map { |d| d[0] },
      values: data.map { |d| d[1] },
      title: "Hours played",
      yAxisLabel: "Hours played"
    }
  end

  sig { returns(T::Array[Array]) }
  def self.reservations_per_day
    Rails.cache.fetch "reservations_per_day_#{Date.current}", expires_in: 1.hour do
      Reservation.where(starts_at: 50.days.ago..)
                 .group(Arel.sql("DATE(starts_at)"))
                 .order(Arel.sql("DATE(starts_at) DESC"))
                 .limit(50)
                 .pluck(Arel.sql("DATE(starts_at), COUNT(*)"))
                 .map { |date, count| [ date.to_s, count ] }
                 .reverse
    end
  end

  sig { returns(T::Array[Array]) }
  def self.reserved_hours_per_month
    Rails.cache.fetch "reserved_hours_per_month_#{Date.current}", expires_in: 1.hour do
      result = ActiveRecord::Base.connection.execute(<<~SQL.squish)
        SELECT TO_CHAR(starts_at, 'YYYY-MM') AS year_month,
               SUM(duration) as total_seconds
        FROM reservations
        WHERE starts_at IS NOT NULL AND duration IS NOT NULL
        GROUP BY TO_CHAR(starts_at, 'YYYY-MM')
        ORDER BY TO_CHAR(starts_at, 'YYYY-MM')
      SQL

      result.to_a.map do |row|
        year_month = row["year_month"]
        seconds = row["total_seconds"].to_f
        year, month = year_month.split("-").map(&:to_i)
        date = Date.new(year, month)
        formatted_date = date.strftime("%b %Y")
        hours = (seconds / 3600.0).round
        [ formatted_date, hours ]
      end
    end
  end
end
