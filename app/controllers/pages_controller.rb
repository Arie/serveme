# typed: false
# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[credits faq private_servers server_providers welcome stats no_vatnik not_found error]
  skip_before_action :redirect_if_country_banned, only: %i[no_to_war welcome no_vatnik]
  before_action :require_admin_or_streamer, only: :recent_reservations
  caches_action :welcome, cache_path: -> { "welcome_#{Time.zone}" }, unless: -> { current_user }, expires_in: 30.seconds

  def welcome
    return unless current_user

    @users_reservations = current_user.reservations.includes(user: :groups, server: :location).ordered.first(5)
    @users_games        = Reservation.played_in(current_user.uid).includes(user: :groups, server: :location).limit(5)
  end

  def credits; end

  def recent_reservations
    @recent_reservations = Reservation.order(starts_at: :desc).includes(user: :groups, server: :location).paginate(page: params[:page], per_page: 50)
  end

  def statistics
    @top_10_users_hash   = Statistic.top_10_users
    @top_10_servers_hash = Statistic.top_10_servers
  end

  def chart
    @chart_type = params[:chart_type]

    case @chart_type
    when "reservations_per_day"
      @chart_data = Statistic.reservations_per_day_chart_data
      render "chart_frame", locals: {
        partial_name: "reservations_per_day_graph",
        frame_id: "reservations_chart"
      }
    when "reserved_hours_per_month"
      @chart_data = Statistic.reserved_hours_per_month_chart_data
      render "chart_frame", locals: {
        partial_name: "reserved_hours_per_month",
        frame_id: "hours_chart"
      }
    else
      head :not_found
    end
  end

  def stats
    servers_count = Server.active.count
    servers_for_non_premium_count = Server.active.without_group.count
    servers_for_premium_count = Server.for_donators.active.count
    current_reservations_count = Reservation.current.count
    servers_for_non_premium_in_use = Reservation.current.where(server_id: Server.without_group).count
    servers_for_premium_in_use = Reservation.current.where(server_id: Server.for_donators).count
    current_players_count = PlayerStatistic.joins(:reservation_player)
      .where(created_at: 90.seconds.ago..)
      .distinct
      .count(:steam_uid)

    render json: {
      current_reservations: current_reservations_count,
      current_players: current_players_count,
      servers: servers_count,
      servers_for_premium: servers_for_premium_count,
      servers_for_non_premium: servers_for_non_premium_count,
      servers_for_premium_in_use: servers_for_premium_in_use,
      servers_for_non_premium_in_use: servers_for_non_premium_in_use
    }
  end

  def server_providers; end

  def faq; end

  def private_servers; end

  def no_vatnik
    cookies.permanent[:not_a_vatnik] = (params[:not_a_vatnik] == "true")
    redirect_to root_path
  end

  def not_found
    render "not_found", status: 404, formats: :html
  end

  def error
    Sentry.capture_exception(request.env["action_dispatch.exception"]) if Rails.env.production? && request.env["action_dispatch.exception"]
    render "error", status: 500, formats: :html
  end

  def comtress
    @team_comtress_group = Group.team_comtress_group
    @is_member = current_user.groups.exists?(id: @team_comtress_group.id)

    if request.post?
      if params[:opt_in] == "true"
        group_membership = current_user.group_users.find_or_initialize_by(group: @team_comtress_group)
        group_membership.expires_at = nil
        group_membership.save!
        flash[:notice] = "You have opted into Team Comtress servers."
      elsif params[:opt_out] == "true"
        current_user.group_users.where(group: @team_comtress_group).destroy_all
        flash[:notice] = "You have opted out of Team Comtress servers."
      end
      redirect_to comtress_path
    end
  end
end
