# typed: false
# frozen_string_literal: true

class DonatorsController < ApplicationController
  include DonatorsHelper

  before_action :require_admin, except: :leaderboard
  before_action :require_donator, only: :leaderboard

  def index
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

    latest_orders = Order.completed
                         .joins(:product)
                         .where(user_id: current_page_ids, gift: false)
                         .select("DISTINCT ON (user_id) user_id, products.name as product_name, paypal_orders.created_at as event_time")
                         .order(:user_id, created_at: :desc)

    latest_vouchers = Voucher.joins(:product)
                            .where(claimed_by_id: current_page_ids)
                            .where.not(claimed_at: nil)
                            .select("DISTINCT ON (claimed_by_id) claimed_by_id as user_id, products.name as product_name, claimed_at as event_time")
                            .order(:claimed_by_id, claimed_at: :desc)

    @latest_products = Order.connection.select_all(
      Order.sanitize_sql([
        <<~SQL
          WITH combined AS (
            (#{latest_orders.to_sql})
            UNION ALL
            (#{latest_vouchers.to_sql})
          ),
          ranked AS (
            SELECT user_id, product_name,
                   ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_time DESC) as rn
            FROM combined
          )
          SELECT user_id, product_name FROM ranked WHERE rn = 1
        SQL
      ])
    ).to_h { |row| [ row["user_id"], row["product_name"] ] }
  end

  def leaderboard
    @donators = Order.leaderboard_by_time.first(25)
  end

  def new
    new_donator
    render :new
  end

  def lookup_user
    input = params[:input]
    @users = UserSearchService.new(input).search

    respond_to do |format|
      format.turbo_stream
    end
  end

  def create
    respond_to do |format|
      format.html do
        add_or_extend_donator || (new_donator && render(:new, status: :unprocessable_entity))
      end
    end
  end

  def show
    @user = User.find(params[:id])

    @donator_periods = GroupUser.unscoped
                               .where(user_id: @user.id, group_id: Group.donator_group)
                               .order(created_at: :desc)

    @orders = @user.orders
                   .completed
                   .includes(:product, voucher: :claimed_by)
                   .order(created_at: :desc)

    @redeemed_gifts = Voucher.joins(:order, :product)
                             .where(claimed_by: @user)
                             .includes(order: :user, product: nil)
                             .order(claimed_at: :desc)

    @lifetime_value = @user.orders.completed.joins(:product).sum(:price)
    @total_donations = @user.orders.completed.count
    @total_reservations = @user.reservations.count
    @total_reservation_hours = (@user.total_reservation_seconds / 3600.0).round(1)

    # Calculate total donator time
    @total_donator_time = calculate_total_donator_time(@donator_periods)
  end

  def edit
    find_donator
  end

  def update
    find_donator
    expires_at = params[:group_user][:expires_at]
    @donator.update(expires_at: expires_at)
    flash[:notice] = "Donator updated, new expiration date: #{expires_at}"
    redirect_to donators_path
  end

  private

  def calculate_total_donator_time(periods)
    total_seconds = 0

    periods.each do |period|
      start_time = period.created_at
      end_time = period.expires_at || Time.current

      # If the period is still active, count up to now
      end_time = [ end_time, Time.current ].min

      total_seconds += (end_time - start_time)
    end

    # Convert to a more readable format
    return nil if total_seconds == 0

    # Use a fictional start time to get the duration formatted
    start_time = Time.current - total_seconds
    format_exact_duration(start_time, Time.current)
  end

  def find_donator
    @donator = GroupUser.where(user_id: params[:id],
                               group_id: Group.donator_group).last
  end

  def new_donator
    @donator = GroupUser.new(expires_at: 31.days.from_now)
  end

  def add_or_extend_donator
    user = User.find_by(id: params[:group_user][:user_id])

    return false unless user

    if user.donator?
      gu = user.group_users.where(group_id: Group.donator_group).last
      duration = (Time.parse(params[:group_user][:expires_at]) - Time.current).to_i
      old_expires_at = gu.expires_at
      gu.expires_at = gu.expires_at + duration
      gu.save
      flash[:notice] = "Extended donator from #{I18n.l(old_expires_at, format: :long)} to #{I18n.l(gu.expires_at, format: :long)}"
    else
      user.group_users&.create(group_id: Group.donator_group.id, expires_at: params[:group_user][:expires_at])
      flash[:notice] = "New donator added"
    end
    redirect_to donators_path
  end
end
