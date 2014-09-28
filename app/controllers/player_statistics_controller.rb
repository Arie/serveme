class PlayerStatisticsController < ApplicationController
  before_filter :require_admin

  def index
    @player_statistics = paginate(player_statistics)
  end

  def show_for_reservation_and_player
    @player_statistics = paginate(player_statistics.where("reservation_players.steam_uid = ? AND reservation_players.reservation_id = ?", params[:steam_uid].to_s, params[:reservation_id].to_i))
    render :index
  end

  def show_for_reservation
    @player_statistics = paginate(player_statistics.where("reservation_players.reservation_id = ?", params[:reservation_id].to_i))
    render :index
  end

  def show_for_player
    @player_statistics = paginate(player_statistics.where("reservation_players.steam_uid = ?", params[:steam_uid].to_s))
    render :index
  end

  def show_for_server
    @player_statistics = paginate(player_statistics.where("servers.id = ?", params[:server_id].to_i))
    render :index
  end

  private

  def player_statistics
    PlayerStatistic.order('player_statistics.id DESC').joins(:reservation_player => [:reservation, {:server => :location}])
  end

  def paginate(scope)
    scope.paginate(:page => params[:page], :per_page => 100)
  end

end
