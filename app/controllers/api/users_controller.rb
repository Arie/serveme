class Api::UsersController < Api::ApplicationController

  def show
    @user = User.find_by_uid!(params[:id].to_i)
  end

end
