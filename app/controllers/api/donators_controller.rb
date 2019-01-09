# frozen_string_literal: true
class Api::DonatorsController < Api::ApplicationController

  before_action :require_admin

  def show
    @user = Group.donator_group.users.find_by(uid: params[:id])
    if @user
      @donator = @user.group_users.find_by(group_id: Group.donator_group.id)
      render :show
    else
      head :not_found
    end
  end

  def new
    @user = GroupUser.new
    render :new
  end

  def create
    @user = User.find_by_uid(donator_params[:steam_uid])
    @donator = Group.donator_group.group_users.find_or_initialize_by(user_id: @user.id)
    @donator.expires_at = donator_params[:expires_at]
    @donator.save
    render :show
  end

  def destroy
    group_users = Group.donator_group.group_users.joins(:user).where(users: { uid: params[:id] })
    if group_users.any?
      group_users.update_all(expires_at: 1.second.ago)
      head :no_content
    else
      head :not_found
    end
  end

  def donator_params
    params.require(:donator).permit(:steam_uid, :expires_at)
  end

  private

  def require_admin
    api_user && api_user.admin? || unauthorized
  end
end
