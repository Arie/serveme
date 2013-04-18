class PagesController < ApplicationController

  skip_before_filter :authenticate_user!

  def welcome
    @reservations = Reservation.within_12_hours
    if current_user
      @users_reservations = current_user.reservations.ordered.first(5)
    end
  end

  def credits
  end

  def servers
    @servers = Server.ordered
  end

  def recent_reservations
    @recent_reservations = Statistic.recent_reservations
  end

  def statistics
    @top_10_users_hash   = Statistic.top_10_users
    @top_10_servers_hash = Statistic.top_10_servers
  end

  def server_providers
  end

end
