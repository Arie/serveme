# typed: true
# frozen_string_literal: true

class PrivateServersController < ApplicationController
  before_action :require_private_server_option

  def require_private_server_option
    redirect_to root_path unless current_user&.private_server_option?
  end

  def create
    server_id = params[:private_server][:server_id].to_s

    if eligible_server_ids.include?(server_id.to_i)
      current_user.private_server_id = server_id
      flash[:notice] = "Private server saved"
    else
      flash[:alert] = "You cannot select that server as your private server"
    end

    redirect_to settings_path
  end

  private

  def eligible_server_ids
    ids = Server.active.without_group.pluck(:id)
    current = current_user.private_server
    ids << current.id if current
    ids
  end
end
