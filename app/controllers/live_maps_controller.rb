# typed: true
# frozen_string_literal: true

# The live STV map of any server: signed-in users paste a SourceTV connect string (or an address
# and password), it is checked for an answering SourceTV, and they get sent to the map server
# with a start token (see StvmapToken).
class LiveMapsController < ApplicationController
  def new; end

  def create
    return redirect_to(live_map_path, alert: "The live map is not available here") unless StvmapToken.enabled?

    target = StvConnect.parse(params[:connect].to_s.first(300)).check!
    owner = current_admin || current_league_admin || current_streamer ? nil : current_user.uid
    redirect_to StvmapToken.start_url(connect: target.connect_string, owner: owner), allow_other_host: true
  rescue StvConnect::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end
end
