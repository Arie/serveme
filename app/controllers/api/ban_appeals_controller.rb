# typed: false
# frozen_string_literal: true

module Api
  class BanAppealsController < ApplicationController
    before_action :require_admin

    def user_info
      unless params[:steam_uid].present? || params[:discord_uid].present?
        head :bad_request
        return
      end

      result = BanAppealUserInfoService.new(
        steam_uid: params[:steam_uid],
        discord_uid: params[:discord_uid],
        admin_user: api_user
      ).collect

      render json: result
    end

    private

    def require_admin
      head :forbidden unless api_user&.admin?
    end
  end
end
