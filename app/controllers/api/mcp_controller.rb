# typed: true
# frozen_string_literal: true

module Api
  class McpController < Api::ApplicationController
    # GET /api/mcp/tools
    # Returns list of tools available to the current user
    def tools
      available = Mcp::ToolRegistry.available_tools(current_user)
      render json: { tools: available }
    end

    # POST /api/mcp/execute
    # POST /api/mcp (Streamable HTTP)
    # Handles MCP JSON-RPC requests
    def execute
      handler = Mcp::ProtocolHandler.new(current_user)
      result = handler.handle(request.raw_post)

      if result.nil?
        head :no_content
      else
        render json: result
      end
    end
  end
end
