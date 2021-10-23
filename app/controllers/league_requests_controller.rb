# frozen_string_literal: true

class LeagueRequestsController < ApplicationController
  before_action :require_site_or_league_admin

  def new
    if params[:ip] || params[:steam_uid]
      @results = LeagueRequest.new(current_user, ip: params[:ip], steam_uid: params[:steam_uid], cross_reference: params[:cross_reference]).search
      render :index
    else
      @league_request = LeagueRequest.new(current_user)
      render :new
    end
  end

  def create
    @results = LeagueRequest.new(current_user, ip: request_params[:ip], steam_uid: request_params[:steam_uid], cross_reference: request_params[:cross_reference]).search
    render :index
  end

  private

  def request_params
    params[:league_request].permit(%i[ip steam_uid cross_reference])
  end
end
