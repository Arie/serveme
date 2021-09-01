# frozen_string_literal: true

class PlayerStatisticsController < ApplicationController
  before_action :require_admin_or_streamer

  def index
    @player_statistics = paginate(player_statistics)
  end

  def show_for_reservation_and_player
    @player_statistics = paginate(player_statistics.joins(:reservation_player).where('reservation_players.steam_uid = ? AND reservation_players.reservation_id = ?', params[:steam_uid].to_s, params[:reservation_id].to_i))
    render :index
  end

  def show_for_reservation
    @player_statistics = paginate(player_statistics.joins(:reservation_player).where('reservation_players.reservation_id = ?', params[:reservation_id].to_i))
    render :index
  end

  def show_for_player
    @player_statistics = paginate(player_statistics.joins(:reservation_player).where('reservation_players.steam_uid = ?', params[:steam_uid].to_s))
    render :index
  end

  def show_for_server
    @player_statistics = paginate(player_statistics.joins(:server).where('servers.id = ?', params[:server_id].to_i))
    render :index
  end

  def show_for_ip
    @player_statistics = paginate(player_statistics.joins(:reservation_player).where('reservation_players.ip = ?', IPAddr.new(params[:ip].to_i, Socket::AF_INET).to_s))
    render :index
  end

  def show_for_server_ip
    @player_statistics = paginate(player_statistics.joins(:server).where('servers.ip = ?', params[:server_ip].to_s))
    render :index
  end

  private

  def player_statistics
    PlayerStatistic.order('player_statistics.id DESC').includes(:user, { server: :location }, :reservation)
  end

  def paginate(scope)
    scope.paginate(page: params[:page], per_page: 100)
  end
end
