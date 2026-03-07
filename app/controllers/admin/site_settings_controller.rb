# typed: true
# frozen_string_literal: true

module Admin
  class SiteSettingsController < ApplicationController
    before_action :require_admin

    def edit
      @free_server_limit = SiteSetting.free_server_limit
    end

    def update
      SiteSetting.set("free_server_limit", params[:free_server_limit].presence)
      SiteSetting.set("always_enable_plugins", params[:always_enable_plugins] == "true" ? "true" : "false")
      SiteSetting.set("always_enable_demos_tf", params[:always_enable_demos_tf] == "true" ? "true" : "false")
      SiteSetting.set("show_democheck", params[:show_democheck] == "true" ? "true" : "false")
      redirect_to edit_admin_site_settings_path, notice: "Settings updated."
    end
  end
end
