# typed: false
# frozen_string_literal: true

class StacLogsController < ApplicationController
  before_action :require_site_or_league_admin
  layout 'simple', only: %i[show]

  def index
    @stac_logs = StacLog.joins(:reservation).order('stac_logs.id DESC').paginate(page: params[:page], per_page: 100)
  end

  def show
    @stac_log = StacLog.find(params[:id])
  end

  def notify
    @stac_log = StacLog.find(params[:id])
    processor = StacLogProcessor.new(@stac_log.reservation)
    processor.process_content(@stac_log.contents)
    redirect_to stac_logs_path, notice: 'Discord notification sent'
  end
end
