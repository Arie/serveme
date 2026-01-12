# typed: false
# frozen_string_literal: true

require "opentelemetry-logs-sdk"
require "opentelemetry/exporter/otlp_logs"

# Sends structured logs to OpenTelemetry/SigNoz by subscribing to Rails instrumentation events.
# This runs alongside lograge (which handles disk logging) without interfering with it.
class OtelLogger
  def self.setup!
    logger_provider = OpenTelemetry::SDK::Logs::LoggerProvider.new

    processor = OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(
      OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new(
        endpoint: "#{ENV['OTEL_EXPORTER_OTLP_ENDPOINT']}/v1/logs"
      )
    )

    logger_provider.add_log_record_processor(processor)
    otel_logger = logger_provider.logger(name: Rails.application.class.module_parent_name)

    at_exit { logger_provider.shutdown }

    # Subscribe to Rails request events
    ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      payload = event.payload

      attributes = {
        "http.method" => payload[:method],
        "http.path" => payload[:path],
        "http.status_code" => payload[:status],
        "http.controller" => payload[:controller],
        "http.action" => payload[:action],
        "http.format" => payload[:format],
        "http.duration_ms" => event.duration.round(2),
        "http.view_runtime_ms" => payload[:view_runtime]&.round(2),
        "http.db_runtime_ms" => payload[:db_runtime]&.round(2),
        "http.allocations" => payload[:allocations],
        "user.id" => payload[:user_id],
        "user.ip" => payload[:ip]
      }.compact

      body = "#{payload[:method]} #{payload[:path]} - #{payload[:status]} (#{event.duration.round(2)}ms)"

      otel_logger.on_emit(
        timestamp: Time.now,
        severity_text: payload[:status].to_i >= 400 ? "ERROR" : "INFO",
        body: body,
        attributes: attributes
      )
    end
  end
end
