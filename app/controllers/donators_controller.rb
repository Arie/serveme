# frozen_string_literal: true

class DonatorsController < ApplicationController
  before_action :require_admin, except: :leaderboard
  before_action :require_donator, only: :leaderboard

  def index
    @donators = Group.donator_group.users.order('group_users.id DESC').paginate(page: params[:page], per_page: 20)
  end

  def leaderboard
    @donators = Order.leaderboard.first(25)
  end

  def new
    new_donator
    render :new
  end

  def create
    add_or_extend_donator || new
  end

  def edit
    find_donator
  end

  def update
    find_donator
    expires_at = params[:group_user][:expires_at]
    @donator.update(expires_at: expires_at)
    flash[:notice] = "Donator updated, new expiration date: #{expires_at}"
    redirect_to donators_path
  end

  private

  def find_donator
    @donator = GroupUser.where(user_id: params[:id],
                               group_id: Group.donator_group).last
  end

  def new_donator
    @donator = GroupUser.new(expires_at: 31.days.from_now)
  end

  def add_or_extend_donator
    user = User.where(uid: params[:group_user][:user_id]).first

    return false unless user

    if user.donator?
      gu = user.group_users.where(group_id: Group.donator_group).last
      duration = (Time.parse(params[:group_user][:expires_at]) - Time.current).to_i
      old_expires_at = gu.expires_at
      gu.expires_at = gu.expires_at + duration
      gu.save
      puts "Extended donator from #{I18n.l(old_expires_at, format: :long)} to #{I18n.l(gu.expires_at, format: :long)}"
      flash[:notice] = "Extended donator from #{I18n.l(old_expires_at, format: :long)} to #{I18n.l(gu.expires_at, format: :long)}"
    else
      user.group_users&.create(group_id: Group.donator_group.id, expires_at: params[:group_user][:expires_at])
      flash[:notice] = 'New donator added'
    end
    redirect_to donators_path
  end
end
