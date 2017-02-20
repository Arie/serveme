# frozen_string_literal: true
class UsersController < ApplicationController
  def edit
    @user = current_user
    @vouchers = current_user.vouchers.includes(:product, :claimed_by)
    if @user.has_private_server_option?
      @private_server = PrivateServer.new
    end
  end

  def update
    if current_user.update_attributes(user_params)
      flash[:notice] = "Settings saved"
    end
    redirect_to root_path
  end

  private

  def user_params
    params.require(:user).permit(:logs_tf_api_key, :time_zone)
  end

end
