# typed: true
# frozen_string_literal: true

module Api
  class SdrController < Api::ApplicationController
    def show
      ip_port = params.require(:ip_port)
      @result = SdrResolver.resolve(ip_port)

      head :not_found unless @result
    end
  end
end
