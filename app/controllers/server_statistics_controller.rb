# frozen_string_literal: true
class ServerStatisticsController < ApplicationController

  def index
    @server_statistics = paginate(server_statistics)
  end

  def show_for_reservation
    @server_statistics = paginate(server_statistics.where("server_statistics.reservation_id = ?", params[:reservation_id].to_i))
    render :index
  end

  def show_for_server
    @server_statistics = paginate(server_statistics.where("server_id = ?", params[:server_id].to_i))
    render :index
  end

  private

  def server_statistics
    ServerStatistic.order('server_statistics.id DESC').includes(:reservation, {:server => :location})
  end

  def paginate(scope)
    scope.paginate(:page => params[:page], :per_page => 100)
  end
end
