# typed: false
# frozen_string_literal: true

require "spec_helper"
require Rails.root.join("app/loggers/otel_logger")

describe OtelLogger::OtelBroadcastLogger do
  let(:otel_logger) { double("otel_logger", on_emit: nil) }
  let(:broadcast) { described_class.new(otel_logger) }

  it "forwards info messages with empty attributes when no trace/job context" do
    allow(OpenTelemetry::Trace).to receive(:current_span).and_return(
      OpenTelemetry::Trace::Span::INVALID
    )

    broadcast.add(::Logger::INFO, "hello")

    expect(otel_logger).to have_received(:on_emit).with(
      hash_including(severity_text: "INFO", body: "hello", attributes: {})
    )
  end

  it "tags messages with trace_id/span_id when an OTel span is active" do
    span_context = instance_double(
      OpenTelemetry::Trace::SpanContext,
      valid?: true,
      hex_trace_id: "a" * 32,
      hex_span_id: "b" * 16
    )
    span = instance_double(OpenTelemetry::Trace::Span, context: span_context)
    allow(OpenTelemetry::Trace).to receive(:current_span).and_return(span)

    broadcast.add(::Logger::INFO, "hello")

    expect(otel_logger).to have_received(:on_emit).with(
      hash_including(
        attributes: hash_including(
          "trace.trace_id" => "a" * 32,
          "trace.span_id" => "b" * 16
        )
      )
    )
  end

  it "tags messages with sidekiq jid/worker when running in a job" do
    allow(OpenTelemetry::Trace).to receive(:current_span).and_return(
      OpenTelemetry::Trace::Span::INVALID
    )

    Sidekiq::Context.with(class: "SomeWorker", jid: "abc123") do
      broadcast.add(::Logger::INFO, "job said hi")
    end

    expect(otel_logger).to have_received(:on_emit).with(
      hash_including(
        attributes: hash_including(
          "sidekiq.jid" => "abc123",
          "sidekiq.worker" => "SomeWorker"
        )
      )
    )
  end

  it "skips lograge-formatted broadcast messages" do
    broadcast.add(::Logger::INFO, "method=GET path=/foo status=200")

    expect(otel_logger).not_to have_received(:on_emit)
  end

  it "skips DEBUG messages" do
    broadcast.add(::Logger::DEBUG, "noise")

    expect(otel_logger).not_to have_received(:on_emit)
  end
end
