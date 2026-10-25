# typed: true
# frozen_string_literal: true

module Api
  class LiveMapsController < Api::ApplicationController
    def create
      return render_stv_unavailable unless StvtfToken.enabled?

      target = StvConnect.parse(params.require(:connect).to_s.first(300)).check!
      render_stv_link(target.connect_string)
    rescue StvConnect::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
