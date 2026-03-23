# typed: true
# frozen_string_literal: true

module Admin
  class ScoreboardsController < ApplicationController
    before_action :require_admin

    def index
      @reservations = Reservation.current.includes(:user, :server, :reservation_players)
      @reservations.each do |reservation|
        Sidekiq.redis { |r| r.set("log_listeners:#{reservation.logsecret}", "1", ex: 30) }
      end
    end
  end
end
