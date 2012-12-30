class PagesController < ApplicationController

  skip_before_filter :authenticate_user!

  def welcome
    if just_after_midnight?
      @reservations = Reservation.yesterday
      flash[:alert] = 'No reservations possible between 00:00 and 03:00, servers get rebooted at 03:00'
    else
      @reservations = Reservation.today
    end
    if current_user
      @users_reservation = @reservations.where(:user_id => current_user).first
      if Server.available_today_for_user(current_user).none? && !current_user.todays_reservation
        flash.now[:alert] = "No more servers available today, sorry :("
      end
    end
  end

  def credits
  end

  def recent_reservations
    @recent_reservations  = Statistic.recent_reservations
    @users                = Statistic.recent_users
  end

  def top_10
    @top_10_hash = Statistic.top_10
  end

end
