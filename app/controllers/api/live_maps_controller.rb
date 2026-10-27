# typed: true
# frozen_string_literal: true

module Api
  class LiveMapsController < Api::ApplicationController
    def create
      return render_stv_unavailable unless StvtfToken.enabled?

      input = params.require(:connect).to_s.first(300)
      if (demo = DemostfDemo.parse(input))
        render_stv_link(demo: demo.check!.id)
      else
        render_stv_link(connect: StvConnect.parse(input).check!.connect_string)
      end
    rescue StvConnect::Error, DemostfDemo::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
