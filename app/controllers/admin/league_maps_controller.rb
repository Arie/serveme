# typed: false
# frozen_string_literal: true

module Admin
  class LeagueMapsController < ApplicationController
    before_action :require_config_admin_or_above

    def index
      @sync_service = LeagueMapsSyncService.new
      @last_sync_time = @sync_service.last_sync_time

      @current_config = Rails.cache.read(LeagueMapsSyncService::CACHE_KEY) || { "league_maps" => [] }

      league_maps_data = @current_config.dig("league_maps") || []
      @league_maps = league_maps_data
        .select { |league| league["active"] != false }
        .map { |league| LeagueMaps.new(name: league["name"], maps: (league["maps"] || []).uniq.sort) }
    end

    def fetch
      @sync_service = LeagueMapsSyncService.new

      begin
        @new_config = @sync_service.fetch_from_github

        if @new_config.empty?
          flash[:error] = "Failed to fetch league maps from GitHub. Please check the logs."
          redirect_to admin_league_maps_path
          return
        end

        @validation_result = @sync_service.validate_config(@new_config)

        @current_config = Rails.cache.read(LeagueMapsSyncService::CACHE_KEY) || { "league_maps" => [] }
        @diff = @sync_service.generate_diff(@new_config, @current_config)

        render :preview
      rescue => e
        Rails.logger.error("Error fetching league maps: #{e.message}")
        flash[:error] = "Error fetching league maps: #{e.message}"
        redirect_to admin_league_maps_path
      end
    end

    def apply
      @sync_service = LeagueMapsSyncService.new

      config_param = params[:config]
      unless config_param.present?
        flash[:error] = "No configuration data provided"
        redirect_to admin_league_maps_path
        return
      end

      begin
        config_data = JSON.parse(config_param)

        validation_result = @sync_service.validate_config(config_data)

        unless validation_result[:valid]
          flash[:error] = "Configuration validation failed: #{validation_result[:errors].join(', ')}"
          redirect_to admin_league_maps_path
          return
        end

        success = @sync_service.apply_config(config_data)

        if success
          flash[:success] = "League maps configuration updated successfully!"

          Rails.logger.info(
            "League maps updated by #{current_user.name} (#{current_user.uid}) - " \
            "#{config_data.dig('league_maps')&.size || 0} leagues"
          )

          if validation_result[:warnings].any?
            flash[:warning] = "Applied with warnings: #{validation_result[:warnings].join(', ')}"
          end
        else
          flash[:error] = "Failed to apply configuration"
        end
      rescue JSON::ParserError => e
        flash[:error] = "Invalid configuration data: #{e.message}"
      rescue => e
        Rails.logger.error("Error applying league maps config: #{e.message}")
        flash[:error] = "Error applying configuration: #{e.message}"
      end

      redirect_to admin_league_maps_path
    end

    def force_sync
      success = LeagueMapsSyncService.fetch_and_apply

      if success
        flash[:success] = "League maps synced successfully from GitHub!"
      else
        flash[:error] = "Failed to sync league maps. Check logs for details."
      end

      redirect_to admin_league_maps_path
    end
  end
end
