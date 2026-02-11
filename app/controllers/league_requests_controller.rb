# typed: false
# frozen_string_literal: true

class LeagueRequestsController < ApplicationController
  before_action :require_site_or_league_admin

  def new
    respond_to do |format|
      if params[:ip] || params[:steam_uid]
        @league_request_params = {
          ip: params[:ip],
          steam_uid: params[:steam_uid],
          reservation_ids: params[:reservation_ids],
          cross_reference: params[:cross_reference]
        }
        league_request = LeagueRequest.new(current_user, **@league_request_params)
        @results = league_request.search
        if @results
          @asns = LeagueRequest.lookup_asns(@results)

          unique_ips = @results.map(&:ip).compact.uniq
          unique_uids = @results.map(&:steam_uid).compact.uniq

          @banned_ips = {}
          unique_ips.each { |ip| @banned_ips[ip] = ReservationPlayer.banned_ip?(ip) }

          @banned_uids = {}
          unique_uids.each { |uid| @banned_uids[uid] = ReservationPlayer.banned_uid?(uid) }

          @banned_asns = LeagueRequest.precompute_banned_asns(@asns)

          @ip_lookups = IpLookup.where(ip: unique_ips).index_by(&:ip)

          @stac_steam_uids = unique_uids.join(",")

          format.html { render :index }
        else
          format.html { render :new, status: :unprocessable_entity }
        end
      else
        format.html do
          @league_request = LeagueRequest.new(current_user)
          render :new
        end
      end
    end
  end

  def stac_detections
    steam_uids = params[:steam_uids]&.split(",")
    if steam_uids.present?
      league_request = LeagueRequest.new(current_user)
      @stac_detections = league_request.find_stac_detections_for_steam_uids(steam_uids)
    else
      @stac_detections = []
    end
    render partial: "stac_detections"
  end

  def dismiss_proxy
    ip_lookup = IpLookup.find_by!(ip: params[:ip])
    ip_lookup.update!(false_positive: !ip_lookup.false_positive)
    redirect_to league_request_path(
      ip: params[:search_ip],
      steam_uid: params[:search_steam_uid],
      reservation_ids: params[:search_reservation_ids],
      cross_reference: params[:search_cross_reference]
    )
  end

  def create
    respond_to do |format|
      format.html do
        redirect_to league_request_path(
          ip: request_params[:ip],
          steam_uid: request_params[:steam_uid],
          reservation_ids: request_params[:reservation_ids],
          cross_reference: request_params[:cross_reference]
        )
      end
    end
  end

  private

  def request_params
    params[:league_request].permit(%i[ip steam_uid reservation_ids cross_reference])
  end
end
