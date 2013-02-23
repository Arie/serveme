class ApplicationController < ActionController::Base

  include ApplicationHelper

  protect_from_forgery
  before_filter :authenticate_user!
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
    Time.zone = time_zone_from_cookie
    if current_user
      current_user.update_attributes(:time_zone => time_zone_from_cookie)
    end
  end

  def set_default_time_zone
    Time.zone = Rails.configuration.time_zone
  end

  def time_zone_from_cookie
    cookies[:time_zone]
  end
  helper_method :time_zone_from_cookie

end
