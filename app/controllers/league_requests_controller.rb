# typed: false
# frozen_string_literal: true

class LeagueRequestsController < ApplicationController
  before_action :require_site_or_league_admin

  def new
    respond_to do |format|
      if params[:ip] || params[:steam_uid]
        league_request = LeagueRequest.new(current_user, ip: params[:ip], steam_uid: params[:steam_uid], reservation_ids: params[:reservation_ids], cross_reference: params[:cross_reference])
        @results = league_request.search
        if @results
          @stac_detections = league_request.stac_detections(@results)
          @asns = LeagueRequest.lookup_asns(@results)
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
