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
    @map_statistics = MapUpload.map_statistics
    @bucket_objects = sort_bucket_objects(MapUpload.bucket_objects, @map_statistics, params[:sort_by])
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
      format.html do
        MapUpload.delete_bucket_object(params[:id])
        @bucket_objects = MapUpload.bucket_objects
        @map_statistics = MapUpload.map_statistics
        flash[:notice] = "Map #{params[:id]} deleted"

        redirect_to maps_path
      end
    end
  end

  private

  def sort_bucket_objects(objects, statistics, sort_by)
    sort_by_attribute = friendly_sort_name_to_attribute(sort_by)
    sort_by_object = if %i[map_name size].include?(sort_by_attribute)
                       :self
                     else
                       :statistics
                     end
    maybe_reverse(
      objects.sort do |a, b|
        if sort_by_object == :self
          if a[sort_by_attribute] && b[sort_by_attribute]
            a[sort_by_attribute] <=> b[sort_by_attribute]
          else
            a[sort_by_attribute] ? -1 : 1
          end
        else
          stat_a = statistics[a[:map_name]] && statistics[a[:map_name]][sort_by_attribute].to_i
          stat_b = statistics[b[:map_name]] && statistics[b[:map_name]][sort_by_attribute].to_i
          if stat_a && stat_b
            stat_a <=> stat_b
          else
            i = (stat_a ? -1 : 1)
            if reversed_attribute?(sort_by_attribute)
              i * -1
            else
              i
            end
          end
        end
      end, sort_by_attribute
    )
  end

  def friendly_sort_name_to_attribute(sort_by)
    case sort_by
    when 'times-played'
      :times_played
    when 'first-played'
      :first_played
    when 'last-played'
      :last_played
    when 'size'
      :size
    else
      :map_name
    end
  end

  def maybe_reverse(objects, attribute)
    if reversed_attribute?(attribute)
      objects.reverse
    else
      objects
    end
  end

  def reversed_attribute?(attribute)
    %i[times_played last_played size].include?(attribute)
  end
end
