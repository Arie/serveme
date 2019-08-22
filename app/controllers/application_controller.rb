# frozen_string_literal: true
class ApplicationController < ActionController::Base

  include ApplicationHelper

  protect_from_forgery
  before_action :authenticate_user!
  before_action :set_time_zone
  before_action :check_expired_reservations
  before_action :block_users_with_expired_reservations

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
        current_user.update(:time_zone => time_zone_from_cookie)
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

  def current_admin
    if @current_admin.nil?
      @current_admin = begin
                         if current_user && current_user.admin?
                           current_user
                         else
                           false
                         end
                       end
    end
    @current_admin
  end
  helper_method :current_admin

  def current_streamer
    if @current_streamer.nil?
      @current_streamer =  begin
                             if current_user && current_user.streamer?
                               current_user
                             else
                               false
                             end
                           end
    end
    @current_streamer
  end
  helper_method :current_streamer

  def require_admin
    unless current_admin
      redirect_to root_path
    end
  end

  def require_admin_or_streamer
    unless current_admin || current_streamer
      redirect_to root_path
    end
  end

  def require_donator
    unless current_user && current_user.donator?
      flash[:alert] = "Only donators can do that..."
      redirect_to root_path
    end
  end

  def expired_reservation
    @expired_reservation ||= begin
                              if current_user && !(current_user.donator? || current_user.admin?)
                                current_user.
                                  reservations.where('starts_at > ?', 24.hours.ago).
                                  where('inactive_minute_counter = ?', 30).
                                  where('duration < ?', 35.minutes).
                                  last
                              end
                             end
  end

  def check_expired_reservations
    if expired_reservation
      end_time = I18n.l(expired_reservation.starts_at + 24.hours, :format => :short)
      flash[:alert] = "You reserved a server and didn't use it, you are blocked from using #{SITE_HOST} until #{end_time}. Donators never get blocked, you can #{view_context.link_to('DONATE NOW', donate_path)} to lift the ban".html_safe
    end
  end

  def block_users_with_expired_reservations
    if expired_reservation
      redirect_to root_path
    end
  end
end
