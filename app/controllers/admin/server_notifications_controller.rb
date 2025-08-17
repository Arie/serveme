# typed: true
# frozen_string_literal: true

module Admin
  class ServerNotificationsController < ApplicationController
  before_action :require_admin
  before_action :set_server_notification, only: [ :edit, :update, :destroy ]

  def index
    @server_notifications = ServerNotification.order(id: :desc)
    @server_notification = ServerNotification.new
  end

  def edit
    @server_notifications = ServerNotification.order(id: :desc)
    render :index
  end

  def create
    @server_notification = ServerNotification.new(server_notification_params)
    if @server_notification.save
      redirect_to admin_server_notifications_path, notice: "Server notification was successfully created."
    else
      @server_notifications = ServerNotification.order(id: :desc)
      flash.now[:alert] = "Failed to create server notification."
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @server_notification.update(server_notification_params)
      redirect_to admin_server_notifications_path, notice: "Server notification was successfully updated."
    else
      @server_notifications = ServerNotification.order(id: :desc)
      flash.now[:alert] = "Failed to update server notification."
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @server_notification.destroy
    redirect_to admin_server_notifications_path, notice: "Server notification was successfully destroyed."
  end

  private

  def set_server_notification
    @server_notification = ServerNotification.find(params[:id])
  end

  def server_notification_params
    params.require(:server_notification).permit(:message, :notification_type)
  end
  end
end
