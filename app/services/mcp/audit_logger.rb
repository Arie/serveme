# typed: strict
# frozen_string_literal: true

module Mcp
  class AuditLogger
    extend T::Sig

    sig { params(user: User, tool_name: String, arguments: T::Hash[Symbol, T.untyped], result: T::Hash[Symbol, T.untyped], duration_ms: Float).void }
    def self.log_tool_call(user:, tool_name:, arguments:, result:, duration_ms:)
      log_entry = {
        event: "mcp.tool_call",
        timestamp: Time.current.iso8601,
        user_id: user.id,
        user_name: user.name,
        user_uid: user.uid,
        tool_name: tool_name,
        arguments: sanitize_arguments(arguments),
        result_keys: result.keys,
        result_count: extract_result_count(result),
        duration_ms: duration_ms.round(2),
        success: !result.key?(:error)
      }

      Rails.logger.info("[MCP Audit] #{log_entry.to_json}")

      # Also log a human-readable version
      Rails.logger.info(
        "[MCP] User #{user.id} (#{user.name}) called '#{tool_name}' " \
        "with #{arguments.keys.join(', ')} - #{duration_ms.round(2)}ms"
      )
    end

    sig { params(user: User, tool_name: String, error_message: String).void }
    def self.log_permission_denied(user:, tool_name:, error_message:)
      log_entry = {
        event: "mcp.permission_denied",
        timestamp: Time.current.iso8601,
        user_id: user.id,
        user_name: user.name,
        user_uid: user.uid,
        tool_name: tool_name,
        error_message: error_message
      }

      Rails.logger.warn("[MCP Audit] #{log_entry.to_json}")
    end

    sig { params(user: User, error_message: String).void }
    def self.log_error(user:, error_message:)
      log_entry = {
        event: "mcp.error",
        timestamp: Time.current.iso8601,
        user_id: user.id,
        user_name: user.name,
        error_message: error_message
      }

      Rails.logger.error("[MCP Audit] #{log_entry.to_json}")
    end

    sig { params(arguments: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
    private_class_method def self.sanitize_arguments(arguments)
      # Redact potentially sensitive values but keep keys for debugging
      arguments.transform_values do |value|
        case value
        when String
          value.length > 100 ? "#{value[0..100]}..." : value
        when Array
          "[Array with #{value.length} items]"
        when Hash
          "{Hash with #{value.keys.length} keys}"
        else
          value
        end
      end
    end

    sig { params(result: T::Hash[Symbol, T.untyped]).returns(T.nilable(Integer)) }
    private_class_method def self.extract_result_count(result)
      result[:result_count] || result[:total_count] || result[:results]&.size
    end
  end
end
