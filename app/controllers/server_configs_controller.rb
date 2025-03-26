# typed: false
# frozen_string_literal: true

class ServerConfigsController < ApplicationController
  before_action :require_admin

  def index
    @server_configs = ServerConfig.ordered.paginate(page: params[:page], per_page: 50)
  end

  def new
    new_server_config
    render :new
  end

  def create
    respond_to do |format|
      format.html do
        @server_config = ServerConfig.new(params[:server_config].permit(:file, :hidden))

        if @server_config.save
          flash[:notice] = "Server config added"
          redirect_to server_configs_path
        else
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    find_server_config
  end

  def update
    find_server_config
    @server_config.update(params[:server_config].permit(:file, :hidden))
    flash[:notice] = "Server config updated"
    redirect_to server_configs_path
  end

  private

  def find_server_config
    @server_config = ServerConfig.where(id: params[:id]).last
  end

  def new_server_config
    @server_config = ServerConfig.new
  end
end
