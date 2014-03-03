class DonatorsController < ApplicationController

  before_filter :require_admin

  def index
    @donators = Group.donator_group.users.order('group_users.id DESC').paginate(:page => params[:page], :per_page => 20)
  end

  def new
    new_donator
    render :new
  end

  def create
    find_by_user_id = User.where(id: params[:group_user][:user_id]).first
    find_by_uuid    = User.where(uid: params[:group_user][:user_id]).first
    user = find_by_user_id || find_by_uuid
    if user && user.group_users.create(group_id: Group.donator_group.id, expires_at: params[:group_user][:expires_at])
      flash[:notice] = "New donator added"
      redirect_to donators_path
    else
      new
    end
  end

  def edit
    find_donator
  end

  def update
    find_donator
    expires_at = params[:group_user][:expires_at]
    @donator.update_attributes(expires_at: expires_at)
    flash[:notice] = "Donator updated, new expiration date: #{expires_at}"
    redirect_to donators_path
  end

  private

  def find_donator
    @donator = GroupUser.where(user_id:  params[:id],
                               group_id: Group.donator_group).last
  end

  def new_donator
    @donator = GroupUser.new(expires_at: 31.days.from_now)
  end

end
