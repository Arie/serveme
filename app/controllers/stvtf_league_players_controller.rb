# typed: true
# frozen_string_literal: true

# Players as this region's league knows them, for the live STV map (stvtf-web): it fills in a
# room's names with them. Asked with a token sealed with the key the two share.
class StvtfLeaguePlayersController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :redirect_if_country_banned
  skip_before_action :store_current_location

  def index
    return head(:not_found) unless StvtfToken.enabled?
    return head(:forbidden) unless StvtfToken.league?(request.headers["Authorization"].to_s.delete_prefix("Bearer "))

    steam_uids = params[:steam_uids].to_s.split(",").grep(/\A\d{17}\z/)
    render json: { league: LeagueRoster.league, players: LeagueRoster.players(steam_uids) }
  end
end
