# frozen_string_literal: true

module Api
  class LeagueRequestsController < Api::ApplicationController
    before_action :require_site_or_league_admin

    def index
      respond_to do |format|
        @results = LeagueRequest.new(current_user, ip: request_params[:ip], steam_uid: request_params[:steam_uid], reservation_ids: request_params[:reservation_ids], cross_reference: request_params[:cross_reference]).search
        @flagged_ips = LeagueRequest.flag_ips(@results)
        format.json { render :index }
      end
    end

    private

    def request_params
      params[:league_request].permit(%i[ip steam_uid reservation_ids cross_reference])
    end
  end
end
