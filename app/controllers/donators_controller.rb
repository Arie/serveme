# typed: false
# frozen_string_literal: true

class DonatorsController < ApplicationController
  before_action :require_donator_with_custom_message, only: :leaderboard

  def leaderboard
    @donators = Group.donator_group.users
                     .includes(:group_users, :orders)
                     .order(group_users: { id: :desc })
                     .paginate(page: params[:page], per_page: 20)

    current_page_ids = @donators.map(&:id)

    @lifetime_values = User.joins(orders: :product)
                           .where(id: current_page_ids, paypal_orders: { status: "Completed" })
                           .group(:id)
                           .sum(:price)

    @donation_counts = Order.completed
                           .where(user_id: current_page_ids)
                           .group(:user_id)
                           .count

    @last_donation_dates = Order.completed
                               .where(user_id: current_page_ids)
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
