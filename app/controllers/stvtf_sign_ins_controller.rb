# typed: true
# frozen_string_literal: true

# Signs a user in to the rooms of the live STV map (stvtf-web): a room sends them here, they sign
# in (through Steam, if they have not yet), and go back with a token of who they are.
class StvtfSignInsController < ApplicationController
  def show
    return redirect_to(root_path, alert: "The live map is not available here") unless StvtfToken.enabled?

    redirect_to StvtfToken.sign_in_url(user: current_user, path: map_path(params[:return])), allow_other_host: true
  end

  private

  # A page of the map server's own to go back to, never another site.
  def map_path(path)
    path = path.to_s
    path.start_with?("/") && !path.start_with?("//") && !path.match?(/[\\\s]/) ? path : "/"
  end
end
