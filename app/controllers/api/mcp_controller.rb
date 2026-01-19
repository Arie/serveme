# typed: true
# frozen_string_literal: true

module Api
  class McpController < Api::ApplicationController
    before_action :require_admin_or_league_admin

    # GET /api/mcp/tools
    # Returns list of tools available to the current user
    def tools
      available = Mcp::ToolRegistry.available_tools(current_user)
      render json: { tools: available }
    end

    # POST /api/mcp/execute
    # Handles MCP JSON-RPC requests
    def execute
      handler = Mcp::ProtocolHandler.new(current_user)
      result = handler.handle(request.raw_post)
      render json: result
    end

    private

    def require_admin_or_league_admin
      head :forbidden unless current_admin || current_league_admin
    end
  end
end
