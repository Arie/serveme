# typed: false
# frozen_string_literal: true

class DonatorsController < ApplicationController
  before_action :require_donator_with_custom_message, only: :leaderboard

  def leaderboard
    # Get all users who have completed orders with their total days
    all_users_with_days = Order.leaderboard_by_time

    # Get IDs of all donators in a single query
    donator_ids = Group.donator_group.users.pluck(:id).to_set

    # Filter to only include donators
    @donators = all_users_with_days.select { |user, _days| donator_ids.include?(user.id) }

    # Collect additional stats for all donators
    donator_user_ids = @donators.map { |user, _days| user.id }

    @lifetime_values = User.joins(orders: :product)
                           .where(id: donator_user_ids, orders: { status: "Completed" })
                           .group(:id)
                           .sum("products.price")

    @donation_counts = Order.completed
                           .where(user_id: donator_user_ids)
                           .group(:user_id)
                           .count

    @last_donation_dates = Order.completed
                               .where(user_id: donator_user_ids)
                               .group(:user_id)
                               .maximum(:created_at)
  end

  private

  def require_donator_with_custom_message
    return if current_user&.donator?

    flash[:alert] = "This feature is only available for donators"
    redirect_to root_path
  end
end
