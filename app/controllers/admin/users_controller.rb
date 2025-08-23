# typed: false
# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    include DonatorsHelper

    before_action :require_admin
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @users = User.includes(:groups, :group_users, :orders)
                   .order(created_at: :desc)

      if params[:search].present?
        search_term = params[:search]
        @users = @users.where("users.nickname ILIKE ? OR users.name ILIKE ? OR users.uid = ?",
                             "%#{search_term}%", "%#{search_term}%", search_term)
      end

      if params[:group_id].present?
        @users = @users.joins(:groups).where(groups: { id: params[:group_id] })
      end

      @users = @users.paginate(page: params[:page], per_page: 30)

      current_page_ids = @users.map(&:id)

      @lifetime_values = User.joins(orders: :product)
                             .where(id: current_page_ids, paypal_orders: { status: "Completed" })
                             .group(:id)
                             .sum(:price)

      @reservation_counts = Reservation.where(user_id: current_page_ids)
                                      .group(:user_id)
                                      .count

      @last_sign_in_dates = User.where(id: current_page_ids)
                                .where.not(last_sign_in_at: nil)
                                .pluck(:id, :last_sign_in_at)
                                .to_h

      @filtered_groups = Group.where("name NOT LIKE '7656%'").order(:name)
    end

    def show
      @orders = @user.orders.completed.includes(:product).order(created_at: :desc)
      @vouchers = Voucher.where(claimed_by: @user).includes(:product).order(claimed_at: :desc)
      @reservations = @user.reservations.includes(:server).order(created_at: :desc).limit(20)

      @lifetime_value = @orders.joins(:product).sum(:price)
      @total_donations = @orders.count
      @total_reservations = @user.reservations.count
      @total_reservation_hours = (@user.reservations.sum(:duration) / 3600.0).round(1)

      @group_memberships = GroupUser.where(user: @user)
                                   .joins(:group)
                                   .includes(:group)
                                   .order(created_at: :desc)

      if @user.donator?
        donator_periods = GroupUser.where(user: @user, group: Group.donator_group).order(created_at: :desc)

        if donator_periods.any?
          total_time = 0
          donator_periods.each do |period|
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
      end
    end

    def new
      @user = User.new
      lookup_user if params[:uid].present?
    end

    def create
      identifier = user_params[:uid]
      user = find_or_create_user(identifier)

      if user
        redirect_to admin_user_path(user), notice: "User found/created successfully"
      else
        redirect_to new_admin_user_path, alert: "User not found"
      end
    end

    def edit
      @groups = Group.where("name NOT LIKE '7656%'").order(:name)
      @user_groups = @user.group_users.includes(:group)
    end

    def update
      if params[:group_action].present?
        handle_group_action
      elsif params[:user].present?
        if @user.update(user_params)
          redirect_to admin_user_path(@user), notice: "User updated successfully"
        else
          @groups = Group.where("name NOT LIKE '7656%'").order(:name)
          @user_groups = @user.group_users.includes(:group)
          flash.now[:alert] = "Failed to update user"
          render :edit
        end
      end
    end

    def destroy
      if @user.reservations.any?
        redirect_to admin_users_path, alert: "Cannot delete user with reservations"
      else
        @user.destroy
        redirect_to admin_users_path, notice: "User deleted successfully"
      end
    end

    def lookup_user
      input = params[:input] || params[:uid]
      if input.present?
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
          @user = users.first
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
              @user = User.new
              flash.now[:notice] = "Multiple users found"
              render :new
            }
          end
        else
          @user = User.new
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
        @user = User.new
        render :new
      end
    end


    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:uid, :name, :nickname, :latitude, :longitude)
    end

    def find_or_create_user(identifier)
      return nil unless identifier.present?

      if identifier.to_s.match?(/^\d{1,7}$/)
        User.find_by(id: identifier)
      elsif identifier.to_s.match?(/^\d{17}$/)
        User.find_or_create_by(uid: identifier) do |u|
          u.name = identifier
          u.nickname = identifier
        end
      else
        User.find_by(uid: identifier) || User.find_by("nickname ILIKE ?", identifier)
      end
    end

    def handle_group_action
      case params[:group_action]
      when "add"
        add_user_to_group
      when "remove"
        remove_user_from_group
      when "update_expiry"
        update_group_expiry
      end
    end

    def add_user_to_group
      group = Group.find(params[:group_id])
      expires_at = params[:expires_at].present? ? Time.zone.parse(params[:expires_at]) : nil

      if @user.groups.include?(group)
        redirect_to edit_admin_user_path(@user), alert: "User is already in #{group.name}"
      else
        GroupUser.create!(
          user: @user,
          group: group,
          expires_at: expires_at
        )

        redirect_to edit_admin_user_path(@user), notice: "User added to #{group.name}"
      end
    end

    def remove_user_from_group
      group = Group.find(params[:group_id])
      group_user = @user.group_users.find_by(group: group)

      if group_user
        group_user.destroy

        redirect_to edit_admin_user_path(@user), notice: "User removed from #{group.name}"
      else
        redirect_to edit_admin_user_path(@user), alert: "User is not in #{group.name}"
      end
    end

    def update_group_expiry
      group_user = GroupUser.find(params[:group_user_id])
      expires_at = params[:expires_at].present? ? Time.zone.parse(params[:expires_at]) : nil

      if group_user.update(expires_at: expires_at)
        redirect_to edit_admin_user_path(@user), notice: "Group membership updated"
      else
        redirect_to edit_admin_user_path(@user), alert: "Failed to update group membership"
      end
    end
  end
end
