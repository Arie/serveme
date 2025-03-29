# typed: true
# frozen_string_literal: true

class ServersController < ApplicationController
  before_action :require_admin, only: %i[new create edit update restart force_update]

  def index
    @servers = Server.active.includes([ current_reservations: { user: :groups } ], :location, :recent_server_statistics).order(:name)
    if current_admin || current_league_admin || current_streamer
      @latest_server_version = Server.latest_version
      render :admins
    else
      render :index
    end
  end

  def new
    respond_to do |format|
      format.html do
        @server = SshServer.new
      end
    end
  end

  def create
    @server = SshServer.new(permitted_params)

    if @server.save
      flash[:notice] = "Server created"
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @server = Server.find(params[:id])
  end

  def update
    @server = Server.find(params[:id])
    @server.update(permitted_params)

    if @server.save
      flash[:notice] = "Server updated"
      redirect_to servers_path
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def force_update
    respond_to do |format|
      format.html do
        @server = Server.find(params[:id])
        @server.update_columns(update_status: "Updating", update_started_at: Time.current)
        @server.restart
        Turbo::StreamsChannel.broadcast_replace_to "admin-server-list", target: "admin-server-list", partial: "servers/admin_list", locals: { servers: servers, latest_server_version: Server.latest_version }
        head :no_content
      end
    end
  end

  def restart
    respond_to do |format|
      format.html do
        @server = Server.find(params[:id])
        @server.restart
        Turbo::StreamsChannel.broadcast_replace_to "admin-server-list", target: "admin-server-list", partial: "servers/admin_list", locals: { servers: servers, latest_server_version: Server.latest_version }
        head :no_content
      end
    end
  end

  def permitted_params
    (params[:ssh_server] || params[:local_server]).permit(%i[name ip port rcon path active location_id])
  end

  private

  def servers
    @servers = Server.active.includes([ current_reservations: { user: :groups } ], :location, :recent_server_statistics).order(:name)
  end
end
