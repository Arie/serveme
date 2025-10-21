# typed: true
# frozen_string_literal: true

class PlayerStatisticsController < ApplicationController
  before_action :require_admin_or_streamer

  def index
    respond_to do |format|
      @player_statistics = paginate(player_statistics)
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_sdr
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).merge(ReservationPlayer.with_sdr_ip))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_reservation_and_player
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).where(reservation_players: { steam_uid: params[:steam_uid].to_s, reservation_id: params[:reservation_id].to_i }))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_reservation
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).where(reservation_players: { reservation_id: params[:reservation_id].to_i }))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_player
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).where(reservation_players: { steam_uid: params[:steam_uid].to_s }))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_server
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:server).where(servers: { id: params[:server_id].to_i }))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_ip
    respond_to do |format|
      @player_statistics = paginate(player_statistics.joins(:reservation_player).where(reservation_players: { ip: IPAddr.new(params[:ip].to_i, Socket::AF_INET).to_s }))
      render_or_error(format, @player_statistics)
    end
  end

  def show_for_server_ip
    respond_to do |format|
      server = Server.active.find(params[:server_id])
      if server
        @player_statistics = paginate(player_statistics.joins(:server).where(servers: { ip: server.ip }))
        render_or_error(format, @player_statistics)
      else
        format.html { render "not_found", status: 404, formats: :html }
      end
    end
  end

  private

  def render_or_error(format, player_statistics)
    if player_statistics
      @asns = load_asns(player_statistics) if admin?
      format.html { render :index }
    else
      format.html { render :index, status: :unprocessable_entity }
    end
  end

  def load_asns(player_statistics)
    asns = {}
    ips = player_statistics.joins(:reservation_player).reorder("").distinct.pluck("reservation_players.ip").compact

    ips.each do |ip|
      asn = begin
        ReservationPlayer.asn(ip) if ip.present?
      rescue MaxMind::GeoIP2::AddressNotFoundError
        nil
      end
      asns[ip] = asn
    end

    asns
  end

  def player_statistics
    PlayerStatistic.order(id: :desc).includes(:user, { server: :location }, :reservation)
  end

  def paginate(scope)
    scope.paginate(page: params[:page], per_page: 100)
  end
end
