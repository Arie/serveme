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
    @servers = Server.scoped
  end

  def recent_reservations
    @recent_reservations = Statistic.recent_reservations
  end

  def top_10
    @top_10_hash = Statistic.top_10
  end

  def server_providers
  end

end
