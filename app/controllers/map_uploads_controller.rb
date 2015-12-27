# frozen_string_literal: true
class MapUploadsController < ApplicationController

  before_filter :require_donator

  def new
    @map_upload = MapUpload.new
  end

  def create
    @map_upload = MapUpload.new(params[:map_upload])
    @map_upload.user = current_user
    if @map_upload.save
      flash[:notice] = "Map upload succeeded, it can take a few minute for it to get synced to all servers"
      redirect_to new_map_upload_path
    else
      render :new
    end
  end

end
