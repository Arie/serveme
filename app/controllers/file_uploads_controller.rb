# typed: false
# frozen_string_literal: true

class FileUploadsController < ApplicationController
  before_action :require_admin_or_upload_permission

  def new
    @file_upload = FileUpload.new
  end

  def create
    respond_to do |format|
      format.html do
        render :new, status: :unprocessable_entity if params[:file_upload].nil? && return

        @file_upload = FileUpload.new(params[:file_upload].permit(:file))
        @file_upload.user = current_user

        if @file_upload.save
          @file_upload.process_file
          flash[:notice] = "File upload succeeded. It can take a few minutes for it to get synced to all servers."
          redirect_to file_upload_path(@file_upload)
        else
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def show
    @file_upload = FileUpload.includes(:server_uploads).find(params[:id])
    @servers = Server.active.order(:name)

    render :show
  end

  private

  def require_admin_or_upload_permission
    return if current_user.admin? || current_user.file_upload_permission.present?

    flash[:error] = "You don't have permission to upload files"
    redirect_to root_path
  end
end
