# frozen_string_literal: true
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, except: :recent_reservations
  skip_before_action :block_users_with_expired_reservations

  def welcome
    @most_recently_updated_reservation_time = Reservation.maximum(:updated_at).to_i
    if current_user
      @users_reservations = current_user.reservations.includes(user: :groups, server: :location).ordered.first(5)
      @users_games        = Reservation.played_in(current_user.uid).includes(user: :groups, server: :location).limit(5)
    end
  end

  def credits
  end

  def recent_reservations
    @recent_reservations = Reservation.order('starts_at DESC').includes(user: :groups, server: :location).paginate(page: params[:page], per_page: 50)
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
    cookies.permanent[:theme] = if white_theme?
                                  'black'
                                else
                                  'white'
                                end
    redirect_to root_path
  end

  def not_found
    render 'not_found', status: 404, formats: :html
  end

  def error
    Raven.capture_exception(env['action_dispatch.exception']) if Rails.env.production? && env['action_dispatch.exception']
    render 'error', status: 500, formats: :html
  end
end
