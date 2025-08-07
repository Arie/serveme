# typed: false
# frozen_string_literal: true

module DonatorsHelper
  def format_exact_duration(start_time, end_time)
    return nil unless start_time && end_time

    duration_seconds = end_time - start_time

    days = (duration_seconds / 1.day).to_i
    years = days / 365
    remaining_days = days % 365
    months = remaining_days / 30
    days = remaining_days % 30

    parts = []
    parts << "#{years} #{'year'.pluralize(years)}" if years > 0
    parts << "#{months} #{'month'.pluralize(months)}" if months > 0
    parts << "#{days} #{'day'.pluralize(days)}" if days > 0

    parts.join(", ")
  end
end
