# typed: true
# frozen_string_literal: true

class ServerMonitoringController < ApplicationController
  before_action :authenticate_user!

  def index
    @servers = if current_user&.admin?
      Server.active
            .ordered
    else
                 servers_with_current_reservations
    end
    @servers_json = @servers.map { |s| { id: s.id, name: s.name, ip: s.ip, port: s.port, rcon: s.rcon } }.to_json
    @preselected_server_id = determine_preselected_server_id
  end

  def poll
    begin
      return render_error("Server ID is required") if params[:server_id].blank?

      server = Server.find(params[:server_id])

      return render_error("Access denied - you can only monitor servers with your current reservations") if !current_user&.admin? && !user_can_monitor_server?(server)

      server_info = ServerInfo.new(server)
      stats = server_info.fetch_realtime_stats

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "server_metrics",
            partial: "server_monitoring/metrics",
            locals: {
              stats: stats,
              server_id: server.id,
              timestamp: Time.current.strftime("%H:%M:%S")
            }
          )
        end
      end
    rescue Errno::ECONNREFUSED => e
      render_error("Connection refused")
    rescue ActiveRecord::RecordNotFound => e
      render_error("Server not found")
    rescue => e
      render_error(e.message)
    end
  end

  private

  def servers_with_current_reservations
    Server.active
          .ordered
          .joins(:current_reservations)
          .where(reservations: { user_id: current_user.id })
          .distinct
  end

  def user_can_monitor_server?(server)
    server.current_reservations.exists?(user_id: current_user.id)
  end

  def require_admin
    unless current_user&.admin?
      respond_to do |format|
        format.html { redirect_to root_path }
        format.turbo_stream { head :forbidden }
      end
    end
  end

  def render_error(message)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "server_metrics",
          partial: "server_monitoring/error",
          locals: { error: message }
        )
      end
    end
  end

  def determine_preselected_server_id
    return params[:server_id].to_i if params[:server_id].present? && params[:server_id].to_i > 0

    return @servers.first.id if @servers.count == 1

    nil
  end
end
