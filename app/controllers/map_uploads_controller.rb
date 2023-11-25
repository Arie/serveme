# frozen_string_literal: true

class MapUploadsController < ApplicationController
  skip_before_action :authenticate_user!, only: :index
  before_action :require_donator, only: %i[new create]
  before_action :require_admin, only: :destroy

  layout 'maps', only: :index

  def new
    @map_upload = MapUpload.new
  end

  def index
    @bucket_objects = MapUpload.bucket_objects
    @map_statistics = MapUpload.map_statistics
    if current_admin
      render :admin_index
    else
      render :index
    end
  end

  def create
    respond_to do |format|
      format.html do
        render :new, status: :unprocessable_entity if params[:map_upload].nil? && return

        @map_upload = MapUpload.new(params[:map_upload].permit(:file))
        @map_upload.user = current_user

        if @map_upload.save
          flash[:notice] = 'Map upload succeeded. It can take a few minutes for it to get synced to all servers.'
          redirect_to new_map_upload_path
        else
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    respond_to do |format|
      MapUpload.delete_bucket_object(params[:id])
      @bucket_objects = MapUpload.bucket_objects
      @map_statistics = MapUpload.map_statistics
      flash[:notice] = "Map #{params[:id]} deleted"
      format.html { render :index }
    end
  end
end
