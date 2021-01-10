# frozen_string_literal: true

class UsersController < ApplicationController
  def edit
    @user = current_user
    @vouchers = current_user.vouchers.includes(:product, :claimed_by)
    @private_server = PrivateServer.new if @user.private_server_option?
  end

  def update
    flash[:notice] = 'Settings saved' if current_user.update(user_params)
    redirect_to root_path
  end

  private

  def user_params
    params.require(:user).permit(:logs_tf_api_key, :demos_tf_api_key, :time_zone)
  end
end
