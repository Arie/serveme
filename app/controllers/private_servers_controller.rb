class PrivateServersController < ApplicationController

  before_filter :require_private_server_option

  def require_private_server_option
    unless current_user && current_user.has_private_server_option?
      redirect_to root_path
    end
  end

  def create
    current_user.private_server_id = params[:private_server][:server_id]
    flash[:notice] = "Private server saved"
    redirect_to settings_path
  end

end
