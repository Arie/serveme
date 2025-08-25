# typed: false
# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    include DonatorsHelper

    before_action :require_admin
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @users = build_users_query
      @users = apply_search_filter(@users)
      @users = apply_group_filter(@users)
      @users = apply_sorting(@users)
      @users = @users.paginate(page: params[:page], per_page: 30)

      load_user_statistics
      @filtered_groups = Group.non_private.order(:name)

      respond_to do |format|
        format.html do
          if turbo_frame_request?
            render partial: "users_list", layout: false
          end
        end
        format.turbo_stream do
          Rails.logger.debug "Rendering turbo_stream for users index"
          render turbo_stream: turbo_stream.replace("users_list", partial: "users_list")
        end
      end
    end

    def show
      load_user_details
      calculate_user_statistics
      calculate_donator_time
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
      @groups = Group.non_private.order(:name)
      @user_groups = @user.group_users.includes(:group)
    end

    def update
      if params[:group_action].present?
        handle_group_action
      elsif params[:user].present?
        if @user.update(user_params)
          redirect_to admin_user_path(@user), notice: "User updated successfully"
        else
          @groups = Group.non_private.order(:name)
          @user_groups = @user.group_users.includes(:group)
          flash.now[:alert] = "Failed to update user"
          render :edit
        end
      end
    end

    def lookup_user
      input = params[:input] || params[:uid]
      return render_new_user unless input.present?

      users = find_users_by_input(input)
      handle_lookup_response(users)
    end


    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:uid, :name, :nickname, :latitude, :longitude)
    end

    def build_users_query
      User.includes(:groups, :group_users, :orders)
    end

    def apply_search_filter(users)
      return users unless params[:search].present?

      search_term = params[:search]
      users.where("users.nickname ILIKE :search OR users.name ILIKE :search OR users.uid = :exact",
                  search: "%#{search_term}%", exact: search_term)
    end

    def apply_group_filter(users)
      return users unless params[:group_id].present?
      users.joins(:groups).where(groups: { id: params[:group_id] })
    end

    def apply_sorting(users)
      if filtering_by_donator_group?
        sort_by_last_donation(users)
      else
        users.order(created_at: :desc)
      end
    end

    def filtering_by_donator_group?
      params[:group_id].present? && params[:group_id].to_i == Group.donator_group.id
    end

    def sort_by_last_donation(users)
      last_donations = Order.completed
                           .group(:user_id)
                           .select("user_id, MAX(created_at) as last_donation_date")

      users
        .joins(Arel.sql("LEFT JOIN (#{last_donations.to_sql}) AS last_donations ON last_donations.user_id = users.id"))
        .order(Arel.sql("last_donations.last_donation_date DESC NULLS LAST"))
    end

    def load_user_statistics
      current_page_ids = @users.map(&:id)

      @lifetime_values = calculate_lifetime_values(current_page_ids)
      @reservation_counts = calculate_reservation_counts(current_page_ids)
      @last_sign_in_dates = get_last_sign_in_dates(current_page_ids)
      @last_donation_dates = filtering_by_donator_group? ? get_last_donation_dates(current_page_ids) : {}
    end

    def calculate_lifetime_values(user_ids)
      User.joins(orders: :product)
          .where(id: user_ids, paypal_orders: { status: "Completed" })
          .group(:id)
          .sum(:price)
    end

    def calculate_reservation_counts(user_ids)
      Reservation.where(user_id: user_ids)
                 .group(:user_id)
                 .count
    end

    def get_last_sign_in_dates(user_ids)
      User.where(id: user_ids)
          .where.not(last_sign_in_at: nil)
          .pluck(:id, :last_sign_in_at)
          .to_h
    end

    def get_last_donation_dates(user_ids)
      Order.completed
           .where(user_id: user_ids)
           .group(:user_id)
           .maximum(:created_at)
    end

    def load_user_details
      @orders = @user.orders.completed.includes(:product).order(created_at: :desc)
      @vouchers = Voucher.where(claimed_by: @user).includes(:product).order(claimed_at: :desc)
      @reservations = @user.reservations.includes(:server).order(created_at: :desc).limit(20)
      # Load ALL group memberships including expired ones
      @group_memberships = GroupUser.where(user: @user).joins(:group).includes(:group).order(created_at: :desc)
      @map_uploads = @user.map_uploads.includes(file_attachment: :blob).order(created_at: :desc)

      # Create lookup hash of file sizes for CarrierWave uploads to avoid N+1 queries
      carrierwave_uploads = @map_uploads.select { |upload| !upload.file.attached? && upload[:file].present? }
      if carrierwave_uploads.any?
        bucket_objects = MapUpload.bucket_objects
        @file_size_lookup = {}
        @file_exists_lookup = {}
        carrierwave_uploads.each do |upload|
          bucket_key = "maps/#{upload[:file]}"
          bucket_object = bucket_objects.find { |obj| obj[:key] == bucket_key }
          @file_size_lookup[upload.id] = bucket_object&.[](:size)
          @file_exists_lookup[upload.id] = bucket_object.present?
        end
      end
    end

    def calculate_user_statistics
      @lifetime_value = @orders.joins(:product).sum(:price)
      @total_donations = @orders.count
      @total_reservations = @user.reservations.count
      @total_reservation_hours = (@user.reservations.sum(:duration) / 3600.0).round(1)
      @total_map_uploads = @user.map_uploads.count
    end

    def calculate_donator_time
      donator_periods = @group_memberships.select { |gm| gm.group.name == "Donators" }
      return unless donator_periods.any?

      total_time = calculate_total_donator_time(donator_periods)
      @total_donator_time = format_duration(total_time) if total_time > 0
    end

    def calculate_total_donator_time(periods)
      periods.sum { |period| period.expires_at ? (period.expires_at - period.created_at) : 0 }
    end

    def format_duration(total_time)
      years = (total_time / 1.year).floor
      months = ((total_time % 1.year) / 1.month).floor
      days = ((total_time % 1.month) / 1.day).floor

      parts = []
      parts << "#{years} #{'year'.pluralize(years)}" if years > 0
      parts << "#{months} #{'month'.pluralize(months)}" if months > 0
      parts << "#{days} #{'day'.pluralize(days)}" if days > 0 && parts.empty?

      parts.join(", ")
    end

    def find_users_by_input(input)
      if steam_id64?(input)
        user = User.find_or_create_by(uid: input) do |u|
          u.name = input
          u.nickname = input
        end
        [ user ]
      else
        users = User.where(uid: input)
        users = User.where("nickname ILIKE :search", search: "%#{input}%").limit(10) if users.empty?
        users
      end
    end

    def handle_lookup_response(users)
      case users.count
      when 0
        render_no_users_found
      when 1
        render_single_user_found(users.first)
      else
        render_multiple_users_found(users)
      end
    end

    def render_new_user
      @user = User.new
      render :new
    end

    def render_no_users_found
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

    def render_single_user_found(user)
      @user = user
      @users = [ user ]
      respond_to do |format|
        format.turbo_stream
        format.html { render :new }
      end
    end

    def render_multiple_users_found(users)
      @users = users
      respond_to do |format|
        format.turbo_stream
        format.html {
          @user = User.new
          flash.now[:notice] = "Multiple users found"
          render :new
        }
      end
    end

    def find_or_create_user(identifier)
      return nil unless identifier.present?

      if identifier.to_s.match?(/^\d{1,7}$/)
        User.find_by(id: identifier)
      elsif steam_id64?(identifier)
        User.find_or_create_by(uid: identifier) do |u|
          u.name = identifier
          u.nickname = identifier
        end
      else
        User.find_by(uid: identifier) || User.find_by("nickname ILIKE :identifier", identifier: identifier)
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

    def steam_id64?(input)
      input.to_s.match?(/^\d{17}$/)
    end
  end
end
