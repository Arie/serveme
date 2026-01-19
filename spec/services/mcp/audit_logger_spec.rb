# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::AuditLogger do
  let(:user) { create(:user, :admin) }

  describe ".log_tool_call" do
    it "logs tool call to Rails logger with MCP Audit prefix" do
      allow(Rails.logger).to receive(:info)

      described_class.log_tool_call(
        user: user,
        tool_name: "test_tool",
        arguments: { query: "test" },
        result: { results: [], result_count: 0 },
        duration_ms: 123.45
      )

      expect(Rails.logger).to have_received(:info).with(/\[MCP Audit\]/)
    end

    it "includes user information in JSON log" do
      allow(Rails.logger).to receive(:info)

      described_class.log_tool_call(
        user: user,
        tool_name: "test_tool",
        arguments: {},
        result: {},
        duration_ms: 0.0
      )

      expect(Rails.logger).to have_received(:info).with(/user_id":#{user.id}/)
    end

    it "sanitizes long string arguments in JSON log" do
      allow(Rails.logger).to receive(:info)

      long_string = "a" * 200

      described_class.log_tool_call(
        user: user,
        tool_name: "test_tool",
        arguments: { query: long_string },
        result: {},
        duration_ms: 0.0
      )

      # The full string should not appear in the JSON log (it gets truncated)
      expect(Rails.logger).to have_received(:info).with(/\[MCP Audit\].*\.\.\./)
    end
  end

  describe ".log_permission_denied" do
    it "logs permission denied as warning" do
      expect(Rails.logger).to receive(:warn).with(/MCP Audit.*permission_denied/)

      described_class.log_permission_denied(
        user: user,
        tool_name: "admin_tool",
        error_message: "No permission"
      )
    end
  end

  describe ".log_error" do
    it "logs error to Rails logger" do
      expect(Rails.logger).to receive(:error).with(/MCP Audit.*error/)

      described_class.log_error(
        user: user,
        error_message: "Something went wrong"
      )
    end
  end
end
