class UsersController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    current_user.update_attributes(:logs_tf_api_key => params[:user][:logs_tf_api_key].to_s)
    flash[:notice] = "logs.tf API key set"
    redirect_to root_path
  end

end
