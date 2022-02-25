# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ApplicationHelper

  protect_from_forgery
  before_action :authenticate_user!
  before_action :set_time_zone
  before_action :redirect_if_country_banned

  def set_time_zone
    set_time_zone_from_current_user || set_time_zone_from_cookie || set_default_time_zone
  end

  private

  def set_time_zone_from_current_user
    return if current_user&.time_zone.blank?

    Time.zone = current_user.time_zone
  end

  def set_time_zone_from_cookie
    Time.zone = time_zone_from_cookie
    current_user&.update(time_zone: time_zone_from_cookie)
  rescue ArgumentError
    set_default_time_zone
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

  def current_streamer
    @current_streamer ||= current_user&.streamer? && current_user
  end
  helper_method :current_streamer

  def require_admin
    redirect_to root_path unless current_admin
  end

  def require_admin_or_streamer
    redirect_to root_path unless current_admin || current_league_admin || current_streamer
  end

  def require_site_or_league_admin
    redirect_to root_path unless current_admin || current_league_admin
  end

  def require_donator
    return if current_user&.donator?

    flash[:alert] = 'Only donators can do that...'
    redirect_to root_path
  end

  protected

  def authenticate_user!
    if user_signed_in?
      if current_user.banned?
        Rails.logger.info "Logging out banned player with uid #{current_user.uid}, IP #{current_user.current_sign_in_ip}, name #{current_user.name}"
        sign_out_and_redirect(current_user)
      else
        super
      end
    else
      session[:user_return_to] = request.url
      flash[:notice] = 'Please log in first'
      redirect_to new_session_path
    end
  end

  def redirect_if_country_banned
    redirect_to no_to_war_path if current_user&.banned_country? || ReservationPlayer.banned_country?(request.remote_ip)
  end
end
