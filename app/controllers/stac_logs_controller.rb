# typed: true
# frozen_string_literal: true

class StacLogsController < ApplicationController
  before_action :require_site_or_league_admin

  def index
    @stac_logs = StacLog.joins(:reservation).order(id: :desc).paginate(page: params[:page], per_page: 100)
  end
end
