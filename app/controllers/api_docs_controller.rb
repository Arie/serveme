# typed: false
# frozen_string_literal: true

class ApiDocsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :redirect_if_country_banned
  def swagger_spec
    swagger_file = Rails.root.join("swagger", "v1", "swagger.yaml")
    swagger_content = YAML.load_file(swagger_file)

    current_host = "#{request.protocol}#{request.host_with_port}"
    current_description = if request.host.include?("localhost")
                           "Development server (current)"
    elsif request.host == "serveme.tf"
                           "Production server (EU) - current"
    elsif request.host == "na.serveme.tf"
                           "Production server (NA) - current"
    elsif request.host == "au.serveme.tf"
                           "Production server (AU) - current"
    elsif request.host == "sea.serveme.tf"
                           "Production server (SEA) - current"
    else
                           "Current server"
    end

    current_server = {
      "url" => current_host,
      "description" => current_description
    }

    swagger_content["servers"] = swagger_content["servers"].reject { |s| s["url"] == current_host }
    swagger_content["servers"].unshift(current_server)

    render plain: swagger_content.to_yaml, content_type: "application/yaml"
  end
end
