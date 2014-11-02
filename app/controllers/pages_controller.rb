class PagesController < ApplicationController

  skip_before_filter :authenticate_user!
  skip_before_filter :block_users_with_expired_reservations
  caches_action :credits, :statistics, :server_providers, :faq, :unless => :current_user, expires_in: 1.minute

  def welcome
    @most_recently_updated_reservation_time = Reservation.maximum(:updated_at).to_i
    @reservations = Reservation.within_12_hours.first(50)
    if current_user
      @users_reservations = current_user.reservations.ordered.first(5)
      @users_games        = Reservation.played_in(current_user.uid).limit(5)
    end
  end

  def credits
  end

  def recent_reservations
    @recent_reservations = Reservation.order('starts_at DESC').joins(:server).paginate(:page => params[:page], :per_page => 50)
  end

  def statistics
    @top_10_users_hash   = Statistic.top_10_users
    @top_10_servers_hash = Statistic.top_10_servers
  end

  def server_providers
  end

  def faq
  end

  def private_servers
  end

  def switch_theme
    if black_theme?
      cookies[:theme] = "white"
    else
      cookies[:theme] = "black"
    end
    redirect_to root_path
  end

  def not_found
    render 'not_found', :status => 404
  end

  def error
    Raven.capture_exception(env["action_dispatch.exception"]) if (Rails.env.production? && env["action_dispatch.exception"])
    render 'error', :status => 500
  end
end
