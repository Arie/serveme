# typed: false
# frozen_string_literal: true

module Admin
  class DonatorsController < ApplicationController
    include DonatorsHelper

    before_action :require_admin
    before_action :set_donator, only: [ :show, :edit, :update ]

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
                              .select("DISTINCT ON (claimed_by_id) claimed_by_id as user_id, products.name as product_name, vouchers.claimed_at as event_time")
                              .order(:claimed_by_id, claimed_at: :desc)

      latest_events = ActiveRecord::Base.connection.execute(<<-SQL)
        WITH combined_events AS (
          SELECT user_id, product_name, event_time FROM (#{latest_orders.to_sql}) AS orders
          UNION ALL
          SELECT user_id, product_name, event_time FROM (#{latest_vouchers.to_sql}) AS vouchers
        )
        SELECT DISTINCT ON (user_id) user_id, product_name
        FROM combined_events
        ORDER BY user_id, event_time DESC;
      SQL

      @latest_products = latest_events.each_with_object({}) do |row, hash|
        hash[row["user_id"]] = row["product_name"]
      end
    end

    def new
      @donator = User.new
      lookup_user if params[:uid].present?
    end

    def create
      handle_donator_creation
    end

    def show
      @orders = @donator.orders.completed.includes(:product).order(created_at: :desc)
      @vouchers = Voucher.where(claimed_by: @donator).includes(:product).order(claimed_at: :desc)

      # Calculate statistics
      @lifetime_value = @orders.joins(:product).sum(:price)
      @total_donations = @orders.count
      @total_reservations = @donator.reservations.count
      @total_reservation_hours = (@donator.reservations.sum(:duration) / 3600.0).round(1)

      # Get donator periods (including expired ones)
      @donator_periods = GroupUser.where(user: @donator, group: Group.donator_group).order(created_at: :desc)

      # Calculate total donator time
      if @donator_periods.any?
        total_time = 0
        @donator_periods.each do |period|
          if period.expires_at
            total_time += (period.expires_at - period.created_at)
          end
        end

        if total_time > 0
          years = (total_time / 1.year).floor
          months = ((total_time % 1.year) / 1.month).floor
          days = ((total_time % 1.month) / 1.day).floor

          parts = []
          parts << "#{years} #{'year'.pluralize(years)}" if years > 0
          parts << "#{months} #{'month'.pluralize(months)}" if months > 0
          parts << "#{days} #{'day'.pluralize(days)}" if days > 0 && parts.empty?

          @total_donator_time = parts.join(", ")
        end
      end

      # Get redeemed gifts
      @redeemed_gifts = @vouchers
    end

    def edit
      @latest_donator_until = calculate_latest_donator_until(@donator)
    end

    def update
      result = if params[:extend_donator_status] == "1"
                 extend_donator_status
      elsif params[:expire_donator_status] == "1"
                 expire_donator_status
      else
                 update_donator_until
      end

      if result
        redirect_to admin_donators_path, notice: "Donator status updated"
      else
        flash.now[:alert] = "Failed to update donator status"
        render :edit
      end
    end

    def lookup_user
      input = params[:input] || params[:uid]
      if input.present?
        # For Steam ID64 format, create user if not found
        if input.to_s.match?(/^\d{17}$/)
          user = User.find_or_create_by(uid: input) do |u|
            u.name = input
            u.nickname = input
          end
          users = [ user ]
        else
          users = User.where(uid: input)

          if users.empty?
            users = User.where("nickname ILIKE ?", "%#{input}%").limit(10)
          end
        end

        if users.count == 1
          @donator = users.first
          @users = users
          respond_to do |format|
            format.turbo_stream
            format.html { render :new }
          end
        elsif users.count > 1
          @users = users
          respond_to do |format|
            format.turbo_stream
            format.html {
              @donator = User.new
              flash.now[:notice] = "Multiple users found"
              render :new
            }
          end
        else
          @donator = User.new
          @users = []
          respond_to do |format|
            format.turbo_stream
            format.html {
              flash.now[:alert] = "User not found"
              render :new
            }
          end
        end
      else
        @donator = User.new
        render :new
      end
    end

    private

    def set_donator
      @donator = User.find(params[:id])
    end

    def donator_params
      params.require(:user).permit(:id, :uid)
    end

    def handle_donator_creation
      identifier = donator_params[:id] || donator_params[:uid]
      user = find_or_create_user(identifier)

      if user
        if user.donator?
          redirect_to edit_admin_donator_path(user), alert: "User is already a donator"
        else
          add_donator_status(user, identifier)
        end
      else
        redirect_to new_admin_donator_path, alert: "User not found"
      end
    end

    def extend_donator_status
      days = params[:extension_days].to_i
      return false if days <= 0

      ActiveRecord::Base.transaction do
        @donator.groups << Group.donator_group unless @donator.donator?
        new_expiry = calculate_new_expiry_date(@donator, days)
        @donator.update!(donator_until: new_expiry)
      end
      true
    rescue
      false
    end

    def expire_donator_status
      @donator.update(donator_until: Time.current)
    end

    def update_donator_until
      return false unless params[:user] && params[:user][:donator_until].present?

      # Find the active GroupUser record for the donator group
      group_user = @donator.group_users.find_by(group: Group.donator_group)

      if group_user
        # Parse the date and update the GroupUser expires_at
        new_date = Time.zone.parse(params[:user][:donator_until])
        group_user.update(expires_at: new_date)
      else
        false
      end
    end

    def calculate_new_expiry_date(user, days)
      base_date = if user.donator_until && user.donator_until.future?
                    user.donator_until
      else
                    Time.current
      end
      base_date + days.days
    end

    def find_or_create_user(identifier)
      return nil unless identifier.present?

      if identifier.to_s.match?(/^\d{1,7}$/) # Likely a database ID
        User.find_by(id: identifier)
      elsif identifier.to_s.match?(/^\d{17}$/) # Steam ID64 format
        User.find_or_create_by(uid: identifier) do |u|
          u.name = identifier
          u.nickname = identifier
        end
      else
        User.find_by(uid: identifier)
      end
    end

    def add_donator_status(user, identifier)
      user.groups << Group.donator_group
      GroupUser.create!(
        user: user,
        group: Group.donator_group,
        expires_at: 1.month.from_now
      )

      message = if user.name == identifier
                  "User added as donator. They will be set up when they first log in with Steam."
      else
                  "User added as donator"
      end

      redirect_to admin_donator_path(user), notice: message
    end

    def calculate_latest_donator_until(user)
      latest_order = user.orders.completed.joins(:product).order(created_at: :desc).first
      latest_voucher = Voucher.where(claimed_by: user).joins(:product).order(claimed_at: :desc).first

      dates = []

      if latest_order
        dates << latest_order.created_at + latest_order.product.days.days
      end

      if latest_voucher
        dates << latest_voucher.claimed_at + latest_voucher.product.days.days
      end

      dates.max
    end
  end
end
