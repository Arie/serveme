# frozen_string_literal: true

class PlayerStatisticsController < ApplicationController
  before_action :require_admin_or_streamer

  def index
    respond_to do |format|
      @player_statistics = paginate(player_statistics)
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_reservation_and_player
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).where('reservation_players.steam_uid = ? AND reservation_players.reservation_id = ?', params[:steam_uid].to_s, params[:reservation_id].to_i))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_reservation
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).where('reservation_players.reservation_id = ?', params[:reservation_id].to_i))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_player
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).where('reservation_players.steam_uid = ?', params[:steam_uid].to_s))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_server
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:server).where('servers.id = ?', params[:server_id].to_i))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_ip
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).where('reservation_players.ip = ?', IPAddr.new(params[:ip].to_i, Socket::AF_INET).to_s))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_server_ip
    respond_to do |format|
      server = Server.active.find(params[:server_id])
      if server
        @player_statistics = paginate(player_statistics.joins(:server).where('servers.ip = ?', server.ip))
        render_or_error(format, @player_statistics)
      else
        format.html { render 'not_found', status: 404, formats: :html }
      end
    end
  end

  private

  def render_or_error(format, player_statistics)
    if player_statistics
      format.html { render :index }
    else
      format.html { render :index, status: :unprocessable_entity }
    end
  end

  def player_statistics
    PlayerStatistic.order('player_statistics.id DESC').includes(:user, { server: :location }, :reservation)
  end

  def paginate(scope)
    scope.paginate(page: params[:page], per_page: 100)
  end
end
