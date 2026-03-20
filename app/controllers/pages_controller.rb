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
    @pagy, @recent_reservations = pagy(Reservation.order(starts_at: :desc).includes(user: :groups, server: :location), limit: 50)
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
    docker_host_slots = DockerHost.active.sum(:max_containers)
    free_server_limit = SiteSetting.free_server_limit
    donator_server_count = Server.for_donators.active.not_cloud.count
    servers_count = Server.active.not_cloud.count + docker_host_slots
    servers_for_non_premium_count = free_server_limit || (Server.active.not_cloud.without_group.count + docker_host_slots)
    servers_for_premium_count = donator_server_count + docker_host_slots - (free_server_limit || 0)
    current_reservations_count = Reservation.current.count
    free_user_reservation_count = SiteSetting.free_user_reservation_count(Time.current, Time.current)
    servers_for_non_premium_in_use = free_server_limit ? free_user_reservation_count : Reservation.current.where(server_id: Server.without_group).count
    servers_for_premium_in_use = current_reservations_count - free_user_reservation_count
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

  def cloud_info
    @cloud_locations = cloud_locations_with_flags

    if request.post? && current_user&.donator?
      if params[:enable] == "true" && !current_user.cloud_member?
        current_user.group_users.find_or_create_by!(group: Group.cloud_group)
        flash[:notice] = "Cloud servers are now enabled! You can launch one from the cloud reservation page."
      elsif params[:disable] == "true"
        current_user.group_users.where(group: Group.cloud_group).destroy_all
        flash[:notice] = "Cloud servers have been disabled."
      end
      redirect_to cloud_info_path
    end
  end

  private

  def cloud_locations_with_flags
    locations = Hash.new { |h, k| h[k] = [] }

    CloudProvider::PROVIDERS.each do |provider_name, klass|
      next if provider_name.in?(%w[hetzner vultr]) && CloudProvider::SITE_REGION.in?(%w[EU NA]) && !current_user&.cloud_server_access?

      klass.locations.each do |_code, info|
        next unless info[:region] == CloudProvider::SITE_REGION || provider_name == "remote_docker" || (provider_name == "docker" && Rails.env.development?)

        locations[info[:country]] << { name: info[:name], flag: info[:flag], provider: provider_name }
      end
    end

    locations.each_value { |locs| locs.uniq! { |l| l[:name] }; locs.sort_by! { |l| l[:name] } }
    locations.sort_by { |country, _| country }.to_h
  end

  public

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
