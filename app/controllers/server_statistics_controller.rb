# typed: true
# frozen_string_literal: true

class ServerStatisticsController < ApplicationController
  def index
    @server_statistics = paginate(server_statistics)
  end

  def show_for_reservation
    @server_statistics = paginate(server_statistics.where(reservation_id: params[:reservation_id].to_i))
    render :index
  end

  def show_for_server
    @server_statistics = paginate(server_statistics.where(server_id: params[:server_id].to_i))
    render :index
  end

  private

  def server_statistics
    ServerStatistic.order(id: :desc).includes(:reservation, server: :location)
  end

  def paginate(scope)
    @pagy, records = pagy(scope, limit: 100)
    records
  end
end
