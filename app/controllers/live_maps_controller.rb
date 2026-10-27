# typed: true
# frozen_string_literal: true

# The live STV map of any server: signed-in users paste a SourceTV connect string (or an address
# and password), it is checked for an answering SourceTV, and they get sent to the map server
# with a start token (see StvtfToken). A demos.tf link plays that demo on the map instead.
class LiveMapsController < ApplicationController
  def new; end

  def create
    return redirect_to(live_map_path, alert: "The live map is not available here") unless StvtfToken.enabled?

    input = params[:connect].to_s.first(300)
    redirect_to start_url(input), allow_other_host: true
  rescue StvConnect::Error, DemostfDemo::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  private

  def start_url(input)
    if (demo = DemostfDemo.parse(input))
      StvtfToken.start_url(demo: demo.check!.id, owner: nil)
    else
      StvtfToken.start_url(connect: StvConnect.parse(input).check!.connect_string, owner: nil)
    end
  end
end
