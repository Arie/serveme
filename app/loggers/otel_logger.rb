# typed: false
# frozen_string_literal: true

require "opentelemetry-logs-sdk"
require "opentelemetry/exporter/otlp_logs"

# Sends structured logs to OpenTelemetry/SigNoz in two ways:
# 1. HTTP request logs via ActiveSupport::Notifications (controller actions with rich attributes)
# 2. Rails.logger output via BroadcastLogger (application-level info/warn/error messages)
#
# Lograge lines are skipped in the broadcast to avoid duplication with the request subscriber.
class OtelLogger
  SEVERITY_MAP = {
    "DEBUG" => "DEBUG",
    "INFO" => "INFO",
    "WARN" => "WARN",
    "ERROR" => "ERROR",
    "FATAL" => "FATAL",
    "UNKNOWN" => "ERROR"
  }.freeze

  # Pattern to detect lograge-formatted lines (already handled by the request subscriber)
  # Matches both regular requests (method=GET) and ActionCable (method= path=)
  LOGRAGE_PATTERN = /\Amethod=\S* path=/

  def self.setup!
    resource = OpenTelemetry::SDK::Resources::Resource.create(
      "service.name" => ENV["OTEL_SERVICE_NAME"]
    )
    logger_provider = OpenTelemetry::SDK::Logs::LoggerProvider.new(resource: resource)

    processor = OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(
      OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new(
        endpoint: "#{ENV['OTEL_EXPORTER_OTLP_ENDPOINT']}/v1/logs"
      )
    )

    logger_provider.add_log_record_processor(processor)
    otel_logger = logger_provider.logger(name: Rails.application.class.module_parent_name)

    at_exit { logger_provider.shutdown }

    setup_request_subscriber(otel_logger)
    setup_rails_logger_broadcast(otel_logger)
  end

  def self.setup_request_subscriber(otel_logger)
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

  def self.setup_rails_logger_broadcast(otel_logger)
    broadcast = OtelBroadcastLogger.new(otel_logger)
    Rails.logger.broadcast_to(broadcast)
  end

  # A minimal Logger that forwards messages to the OpenTelemetry log exporter.
  # Used as a broadcast target for Rails.logger.
  class OtelBroadcastLogger < ::Logger
    def initialize(otel_logger)
      super(nil)
      @otel_logger = otel_logger
    end

    def add(severity, message = nil, progname = nil)
      return true if severity < ::Logger::INFO

      message = yield if message.nil? && block_given?
      message ||= progname

      return true if message.nil?

      body = message.to_s.strip
      return true if body.empty?
      return true if body.match?(LOGRAGE_PATTERN)

      severity_text = SEVERITY_MAP[SEV_LABEL[severity] || "UNKNOWN"] || "INFO"

      @otel_logger.on_emit(
        timestamp: Time.now,
        severity_text: severity_text,
        body: body,
        attributes: {}
      )

      true
    end
  end
end
