# typed: strict
# frozen_string_literal: true

module Mcp
  class ProtocolHandler
    extend T::Sig

    # JSON-RPC 2.0 error codes
    PARSE_ERROR = -32700
    INVALID_REQUEST = -32600
    METHOD_NOT_FOUND = -32601
    INVALID_PARAMS = -32602
    INTERNAL_ERROR = -32603

    sig { params(user: User).void }
    def initialize(user)
      @user = user
    end

    sig { params(request_body: String).returns(T::Hash[Symbol, T.untyped]) }
    def handle(request_body)
      request = parse_request(request_body)
      return request if request[:error]

      process_request(request)
    rescue StandardError => e
      Rails.logger.error("MCP Protocol Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      error_response(nil, INTERNAL_ERROR, "Internal error: #{e.message}")
    end

    private

    sig { returns(User) }
    attr_reader :user

    sig { params(body: String).returns(T::Hash[Symbol, T.untyped]) }
    def parse_request(body)
      JSON.parse(body, symbolize_names: true)
    rescue JSON::ParserError => e
      error_response(nil, PARSE_ERROR, "Parse error: #{e.message}")
    end

    sig { params(request: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
    def process_request(request)
      id = request[:id]
      method = request[:method]

      case method
      when "tools/list"
        handle_tools_list(id)
      when "tools/call"
        handle_tools_call(id, request[:params] || {})
      else
        error_response(id, METHOD_NOT_FOUND, "Method not found: #{method}")
      end
    end

    sig { params(id: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
    def handle_tools_list(id)
      tools = ToolRegistry.available_tools(user)
      success_response(id, { tools: tools })
    end

    sig { params(id: T.untyped, params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
    def handle_tools_call(id, params)
      tool_name = params[:name].to_s
      arguments = params[:arguments] || {}

      tool_class = ToolRegistry.find(tool_name)
      return error_response(id, METHOD_NOT_FOUND, "Tool not found: #{tool_name}") unless tool_class

      unless tool_class.available_to?(user)
        AuditLogger.log_permission_denied(
          user: user,
          tool_name: tool_name,
          error_message: "No permission to use tool"
        )
        return error_response(id, INVALID_REQUEST, "No permission to use tool: #{tool_name}")
      end

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      tool = tool_class.new(user)
      result = tool.execute(arguments.transform_keys(&:to_sym))

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duration_ms = ((end_time - start_time) * 1000).to_f

      AuditLogger.log_tool_call(
        user: user,
        tool_name: tool_name,
        arguments: arguments.transform_keys(&:to_sym),
        result: result,
        duration_ms: duration_ms
      )

      success_response(id, {
        content: [
          {
            type: "text",
            text: result.to_json
          }
        ]
      })
    end

    sig { params(id: T.untyped, result: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
    def success_response(id, result)
      {
        jsonrpc: "2.0",
        id: id,
        result: result
      }
    end

    sig { params(id: T.untyped, code: Integer, message: String).returns(T::Hash[Symbol, T.untyped]) }
    def error_response(id, code, message)
      {
        jsonrpc: "2.0",
        id: id,
        error: {
          code: code,
          message: message
        }
      }
    end
  end
end
