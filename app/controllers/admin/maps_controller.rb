# typed: false
# frozen_string_literal: true

class Admin::MapsController < ApplicationController
  before_action :require_config_admin_or_above

  def index
    raw_statistics = MapUpload.map_statistics
    raw_objects = sort_bucket_objects(MapUpload.bucket_objects, raw_statistics, params[:sort_by])

    @map_statistics = raw_statistics.transform_values do |stat|
      stat.merge(
        first_played_formatted: stat[:first_played]&.strftime("%Y-%m-%d"),
        last_played_formatted: stat[:last_played]&.strftime("%Y-%m-%d")
      )
    end

    @bucket_objects = raw_objects.map do |obj|
      obj.merge(
        size_formatted: "#{(obj[:size] / 1024.0 / 1024.0).round(1)} MB",
        upload_date_formatted: obj[:upload_date]&.strftime("%Y-%m-%d")
      )
    end
  end

  def destroy
    MapUpload.delete_bucket_object(params[:id])
    flash[:notice] = "Map #{params[:id]} deleted"
    redirect_to admin_maps_path
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
    when "times-played"
      :times_played
    when "first-played"
      :first_played
    when "last-played"
      :last_played
    when "size"
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
