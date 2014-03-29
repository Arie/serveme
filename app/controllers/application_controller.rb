class ApplicationController < ActionController::Base

  include ApplicationHelper

  protect_from_forgery
  skip_before_filter :authenticate_user!
  def current_user
    User.first
  end
  before_filter :set_time_zone

  def set_time_zone
    set_time_zone_from_current_user || set_time_zone_from_cookie || set_default_time_zone
  end

  private

  def set_time_zone_from_current_user
    if current_user && current_user.time_zone.present?
      Time.zone = current_user.time_zone
    end
  end

  def set_time_zone_from_cookie
    begin
      Time.zone = time_zone_from_cookie
      if current_user
        current_user.update_attributes(:time_zone => time_zone_from_cookie)
      end
    rescue ArgumentError
      set_default_time_zone
    end
  end

  def set_default_time_zone
    Time.zone = Rails.configuration.time_zone
  end

  def time_zone_from_cookie
    cookies[:time_zone]
  end
  helper_method :time_zone_from_cookie

  def black_theme?
    @black_theme ||= cookies[:theme] == "black"
  end
  helper_method :black_theme?

  def require_admin
    unless current_user && current_user.admin?
      redirect_to root_path
    end
  end

end
