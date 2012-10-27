class ReservationsController < ApplicationController

  before_filter :reservations_open?, :except => [:show, :destroy]

  def new
  end

  def edit
  end

  def show
  end

  def create
    if reservation.persisted?
      params[:reservation].except!(:server_id)
    end
    reservation.attributes  = params[:reservation]
    reservation.user_id     = current_user.id
    reservation.date        = Date.today
    if reservation.save
      reservation.update_configuration
      flash[:notice] = "Reservation created for #{reservation.server_name}. Give the server a minute to (re)boot and <a href='#{reservation.steam_connect_url}'>click here to join</a> or enter in console: #{reservation.connect_string}".html_safe
      redirect_to root_path
    else
      render :new
    end
  end

  def update
    create
  end

  def destroy
    if reservation
      link = "/uploads/#{reservation.zipfile_name}"
      reservation.end_reservation
      flash[:notice] = "Reservation removed, restarting server. Get your STV demos and logs <a href='#{link}' target=_blank>here</a>".html_safe
    else
      flash[:alert] = "Couldn't find an active reservation for #{current_user.nickname}"
    end
    redirect_to root_path
  end

  def reservation
    @reservation ||= begin
      current_user.reservation || new_reservation
    end
  end
  helper_method :reservation

  private

  def new_reservation
    Reservation.new(:user_id => current_user, :date => Date.today)
  end

  def reservations_open?
    if just_after_midnight?
      redirect_to root_path
    end
  end

end
