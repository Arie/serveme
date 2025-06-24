# typed: false
# frozen_string_literal: true

Rswag::Ui.configure do |c|
  c.openapi_endpoint "/api-docs/v1/swagger.yaml", "serveme.tf API V1"
end

Rswag::Api.configure do |c|
  c.openapi_root = Rails.root.join("swagger").to_s
end
