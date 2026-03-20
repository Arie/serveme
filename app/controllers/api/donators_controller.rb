# typed: false
# frozen_string_literal: true

module Api
  class DonatorsController < Api::ApplicationController
    before_action :require_admin

    def show
      @user = User.joins(:group_users).where(group_users: { group_id: Group::DONATOR_GROUP.id }).find_by(uid: params[:id])
      if @user && (@donator = @user.group_users.find_by(group_id: Group::DONATOR_GROUP.id))
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
      if @user
        @donator = GroupUser.find_or_initialize_by(group_id: Group::DONATOR_GROUP.id, user_id: @user.id)
        @donator.expires_at = donator_params[:expires_at]
        @donator.save
        render :show
      else
        head :not_found
      end
    end

    def destroy
      group_users = GroupUser.joins(:user).where(group_id: Group::DONATOR_GROUP.id, users: { uid: params[:id] })
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
      api_user&.admin? || head(:forbidden)
    end
  end
end
