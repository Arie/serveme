# frozen_string_literal: true

class PrivateServersController < ApplicationController
  before_action :require_private_server_option

  def require_private_server_option
    redirect_to root_path unless current_user&.private_server_option?
  end

  def create
    current_user.private_server_id = params[:private_server][:server_id]
    flash[:notice] = 'Private server saved'
    redirect_to settings_path
  end
end
