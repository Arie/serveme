# typed: true
# frozen_string_literal: true

# The Steam uid of one Discord user linked here, for the live STV map (stvtf-web): it knows who is
# who in a team's voice channel by them. Asked with a token for that one user, sealed with the key
# the two share.
class StvtfDiscordLinksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :redirect_if_country_banned
  skip_before_action :store_current_location

  def show
    return head(:not_found) unless StvtfToken.enabled?

    discord_uid = params[:discord_uid].to_s
    return head(:forbidden) unless StvtfToken.link?(request.headers["Authorization"].to_s.delete_prefix("Bearer "), discord_uid)

    steam = User.where(discord_uid: discord_uid).pick(:uid)
    steam ? render(json: { steam: steam }) : head(:not_found)
  end
end
