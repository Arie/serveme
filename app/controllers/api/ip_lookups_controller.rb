# typed: false
# frozen_string_literal: true

module Api
  class IpLookupsController < ApplicationController
    before_action :require_admin

    def create
      ip_lookup = IpLookup.upsert_from_sync(ip_lookup_params)
      render json: { ip_lookup: { id: ip_lookup.id, ip: ip_lookup.ip } }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def require_admin
      head :forbidden unless api_user&.admin?
    end

    def ip_lookup_params
      params.require(:ip_lookup).permit(
        :ip, :is_proxy, :is_residential_proxy, :fraud_score,
        :connection_type, :isp, :country_code, :false_positive,
        :is_banned, :ban_reason, raw_response: {}
      )
    end
  end
end
