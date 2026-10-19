# typed: true
# frozen_string_literal: true

# The live STV map of any server: signed-in users paste a SourceTV connect string and get sent
# to the map server with a start token (see StvmapToken).
class LiveMapsController < ApplicationController
  # Admins only for now.
  before_action :require_admin

  def new; end

  def create
    connect = params[:connect].to_s.strip
    if !StvmapToken.enabled? || connect.blank?
      flash[:alert] = StvmapToken.enabled? ? "Paste a SourceTV connect string" : "The live map is not available here"
      return redirect_to(live_map_path)
    end

    owner = current_admin || current_league_admin || current_streamer ? nil : current_user.uid
    redirect_to StvmapToken.start_url(connect: connect.first(300), owner: owner), allow_other_host: true
  end
end
