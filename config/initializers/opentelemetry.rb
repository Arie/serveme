# typed: strict
# frozen_string_literal: true

if [ "serveme.tf", "na.serveme.tf", "sea.serveme.tf", "au.serveme.tf" ].include?(SITE_HOST)
  ENV["OTEL_EXPORTER"] = "otlp"
  ENV["OTEL_SERVICE_NAME"] = SITE_HOST
  ENV["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://localhost:4318"

  OpenTelemetry::SDK.configure do |c|
    c.use_all
  end
end
