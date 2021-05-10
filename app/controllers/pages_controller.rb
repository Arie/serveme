# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, except: %i[recent_reservations statistics]
  before_action :require_admin_or_streamer, only: :recent_reservations

  def welcome
    return unless current_user

    @users_reservations = current_user.reservations.includes(user: :groups, server: :location).ordered.first(5)
    @users_games        = Reservation.played_in(current_user.uid).includes(user: :groups, server: :location).limit(5)
  end

  def credits; end

  def recent_reservations
    @recent_reservations = Reservation.order('starts_at DESC').includes(user: :groups, server: :location).paginate(page: params[:page], per_page: 50)
  end

  def statistics
    @top_10_users_hash   = Statistic.top_10_users
    @top_10_servers_hash = Statistic.top_10_servers
  end

  def server_providers; end

  def faq; end

  def private_servers; end

  def not_found
    render 'not_found', status: 404, formats: :html
  end

  def error
    Raven.capture_exception(request.env['action_dispatch.exception']) if Rails.env.production? && request.env['action_dispatch.exception']
    render 'error', status: 500, formats: :html
  end
end
