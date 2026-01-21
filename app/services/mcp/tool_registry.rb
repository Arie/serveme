# typed: strict
# frozen_string_literal: true

module Mcp
  class ToolRegistry
    extend T::Sig

    TOOLS = T.let([
      # Admin tools
      Mcp::Tools::SearchAltsTool,
      Mcp::Tools::GetUserTool,
      Mcp::Tools::ListServersTool,
      Mcp::Tools::ListReservationsTool,
      # Public tools (for Discord bot integration)
      Mcp::Tools::GetPublicServersTool,
      Mcp::Tools::GetPlayerReservationsTool,
      Mcp::Tools::LinkDiscordTool,
      Mcp::Tools::GetDiscordLinkTool,
      Mcp::Tools::CreateReservationTool,
      Mcp::Tools::GetReservationStatusTool,
      Mcp::Tools::EndReservationTool
    ].freeze, T::Array[T.class_of(Mcp::Tools::BaseTool)])

    sig { returns(T::Array[T.class_of(Mcp::Tools::BaseTool)]) }
    def self.tools
      TOOLS
    end

    sig { params(name: String).returns(T.nilable(T.class_of(Mcp::Tools::BaseTool))) }
    def self.find(name)
      tools.find { |tool| tool.tool_name == name }
    end

    sig { params(user: User).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
    def self.available_tools(user)
      tools
        .select { |tool| tool.available_to?(user) }
        .map(&:to_mcp_definition)
    end
  end
end
