# typed: true
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend
  include ApplicationHelper

  protect_from_forgery
  before_action :authenticate_user!
  before_action :set_time_zone
  before_action :redirect_if_country_banned
  before_action :store_current_location, unless: :devise_controller?

  def set_time_zone
    set_time_zone_from_current_user || set_time_zone_from_cookie || set_default_time_zone
  end

  private

  def set_time_zone_from_current_user
    return if current_user&.time_zone.blank?

    normalized_tz = normalize_timezone(current_user.time_zone)
    Time.zone = normalized_tz

    if normalized_tz != current_user.time_zone
      current_user.update(time_zone: normalized_tz)
      current_user.reload
    end

    true
  rescue ArgumentError
    current_user.update(time_zone: nil)
    set_default_time_zone
  end

  def set_time_zone_from_cookie
    return if time_zone_from_cookie.blank?

    normalized_tz = normalize_timezone(time_zone_from_cookie)
    Time.zone = normalized_tz

    current_user&.update(time_zone: normalized_tz) if current_user&.time_zone.blank?

    true
  rescue ArgumentError
    set_default_time_zone
  end

  def normalize_timezone(timezone)
    return timezone unless timezone

    # Handle IANA timezone renames that break on newer tzdata
    # Map old names to new names, or vice versa depending on system
    case timezone
    when /Europe\/K(ie|yi)v/
      # Europe/Kiev renamed to Europe/Kyiv (tzdata 2022b)
      find_available_timezone("Europe/Kyiv", "Europe/Kiev") || timezone
    when /America\/Godthab|America\/Nuuk/
      # America/Godthab renamed to America/Nuuk
      find_available_timezone("America/Nuuk", "America/Godthab") || timezone
    when /Asia\/Rangoon|Asia\/Yangon/
      # Asia/Rangoon renamed to Asia/Yangon
      find_available_timezone("Asia/Yangon", "Asia/Rangoon") || timezone
    else
      timezone
    end
  end

  def find_available_timezone(*identifiers)
    identifiers.each do |identifier|
      tz = ActiveSupport::TimeZone[identifier]
      return identifier if tz
    end
    nil
  end

  def set_default_time_zone
    Time.zone = Rails.configuration.time_zone
  end

  def time_zone_from_cookie
    cookies[:time_zone]
  end
  helper_method :time_zone_from_cookie

  def current_admin
    @current_admin ||= current_user&.admin? && current_user
  end
  helper_method :current_admin

  def current_league_admin
    @current_league_admin ||= current_user&.league_admin? && current_user
  end
  helper_method :current_league_admin

  def current_config_admin
    @current_config_admin ||= current_user&.config_admin? && current_user
  end
  helper_method :current_config_admin

  def current_streamer
    @current_streamer ||= current_user&.streamer? && current_user
  end
  helper_method :current_streamer

  def current_trusted_api
    @current_trusted_api ||= current_user&.trusted_api? && current_user
  end
  helper_method :current_trusted_api

  def require_admin
    redirect_to root_path unless current_admin
  end

  def require_admin_or_streamer
    redirect_to root_path unless current_admin || current_league_admin || current_streamer
  end

  def require_site_or_league_admin
    redirect_to root_path unless current_admin || current_league_admin
  end

  def require_config_admin_or_above
    redirect_to root_path unless current_config_admin || current_admin || current_league_admin
  end

  def require_donator
    return if current_user&.donator?

    flash[:alert] = "Only donators can do that..."
    redirect_to root_path
  end

  protected

  def authenticate_user!
    if user_signed_in?
      if current_user.banned?
        ban_reason = current_user.ban_reason
        Rails.logger.info "Logging out banned player with user id #{current_user.id} steam uid #{current_user.uid}, IP #{current_user.current_sign_in_ip}, name #{current_user.name}, reason: #{ban_reason}"
        sign_out(current_user)
        flash[:alert] = "You have been banned: #{ban_reason}"
        redirect_to root_path
      elsif current_user.current_sign_in_ip && ReservationPlayer.banned_asn_ip?(current_user.current_sign_in_ip) && !current_user.admin?
        Rails.logger.info "Logging out player on VPN with user id #{current_user.id} steam uid #{current_user.uid}, IP #{current_user.current_sign_in_ip}, name #{current_user.name}"
        sign_out(current_user)
        flash[:alert] = "You appear to be on a VPN, please log in without it"
        redirect_to root_path
      else
        super
      end
    else
      session[:user_return_to] = request.url
      flash[:notice] = "Please log in first"
      redirect_to new_session_path
    end
  end

  def redirect_if_country_banned
    return if cookies["not_a_vatnik"] == "true" || current_user&.donator? || ReservationPlayer.whitelisted_uid?(current_user&.uid)

    redirect_to no_to_war_path if current_user&.banned_country? || ReservationPlayer.banned_country?(request.remote_ip) || recent_banned_country_ips?
  end

  def recent_banned_country_ips?
    return false unless current_user

    current_user
      .reservation_players
      .joins(:reservation)
      .where(reservations: { created_at: Date.new(2022, 1, 1).. })
      .where.not(ip: nil)
      .distinct
      .pluck(:ip)
      .any? { |ip| ReservationPlayer.banned_country?(ip) }
  end

  def store_current_location
    store_location_for(:user, request.url)
  end

  def distance_unit
    na_system? ? "mi" : "km"
  end
end
