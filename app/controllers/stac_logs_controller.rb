# typed: true
# frozen_string_literal: true

class StacLogsController < ApplicationController
  before_action :require_site_or_league_admin

  def index
    @pagy, @stac_logs = pagy(StacLog.joins(:reservation).order(id: :desc), limit: 100)
  end
end
